import Foundation
import MultipeerConnectivity

@MainActor
@Observable
final class P2PService: NSObject {
    var connectedPeers: [Peer] = []
    var isRunning = false

    private static let serviceType = "aiagent-p2p"  // Max 15 chars, lowercase + hyphens
    private static let peerIdKey = "p2pStablePeerID"

    fileprivate var session: MCSession!
    private var browser: MCNearbyServiceBrowser!
    private var advertiser: MCNearbyServiceAdvertiser!
    private var localMCPeerID: MCPeerID!

    // Maps MCPeerID displayName -> Peer metadata
    private var peerMap: [String: Peer] = [:]
    // Maps MCPeerID displayName -> MCPeerID (for sending)
    private var mcPeerMap: [String: MCPeerID] = [:]

    // Continuation for waiting on incoming messages per threadId
    private var messageContinuations: [UUID: CheckedContinuation<P2PEnvelope, Error>] = [:]

    // Callback for incoming negotiation starts (set by AppState)
    var onIncomingNegotiation: ((P2PEnvelope) -> Void)?

    // MARK: - Stable Peer ID

    private static func stablePeerID() -> String {
        if let existing = UserDefaults.standard.string(forKey: peerIdKey), !existing.isEmpty {
            return existing
        }
        let newId = UUID().uuidString
        UserDefaults.standard.set(newId, forKey: peerIdKey)
        return newId
    }

    // MARK: - Lifecycle

    func start(profile: UserProfile) {
        guard !isRunning else { return }

        let stableId = Self.stablePeerID()
        localMCPeerID = MCPeerID(displayName: stableId)

        session = MCSession(peer: localMCPeerID, securityIdentity: nil, encryptionPreference: .required)
        let delegate = SessionDelegate(service: self)
        session.delegate = delegate
        _sessionDelegate = delegate

        // Discovery info carries our username + avatar so peers can display us
        let discoveryInfo: [String: String] = [
            "username": profile.username,
            "avatarId": profile.avatarId,
        ]

        browser = MCNearbyServiceBrowser(peer: localMCPeerID, serviceType: Self.serviceType)
        browser.delegate = delegate
        browser.startBrowsingForPeers()

        advertiser = MCNearbyServiceAdvertiser(
            peer: localMCPeerID,
            discoveryInfo: discoveryInfo,
            serviceType: Self.serviceType
        )
        advertiser.delegate = delegate
        advertiser.startAdvertisingPeer()

        // Store our own info so we can attach it to outgoing envelopes
        _localPeer = Peer(id: stableId, username: profile.username, avatarId: profile.avatarId)

        isRunning = true
    }

    func stop() {
        guard isRunning else { return }
        browser?.stopBrowsingForPeers()
        advertiser?.stopAdvertisingPeer()
        session?.disconnect()
        connectedPeers = []
        peerMap = [:]
        mcPeerMap = [:]
        cancelAllContinuations()
        isRunning = false
    }

    // MARK: - Send

    func send(_ envelope: P2PEnvelope, to peer: Peer) throws {
        guard let mcPeer = mcPeerMap[peer.id] else {
            throw P2PError.peerNotConnected
        }
        let data = try JSONEncoder().encode(envelope)
        try session.send(data, toPeers: [mcPeer], with: .reliable)
    }

    // MARK: - Receive (async)

    /// Wait for the next message on a given thread. Throws on timeout or disconnection.
    func waitForMessage(threadId: UUID, timeout: TimeInterval = 120) async throws -> P2PEnvelope {
        try await withCheckedThrowingContinuation { continuation in
            messageContinuations[threadId] = continuation

            // Timeout cancellation
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(timeout))
                if let pending = messageContinuations.removeValue(forKey: threadId) {
                    pending.resume(throwing: P2PError.timeout)
                }
            }
        }
    }

    // MARK: - Internal

    private var _sessionDelegate: SessionDelegate?
    private var _localPeer: Peer?

    var localPeer: Peer? { _localPeer }

    func peer(for mcPeerDisplayName: String) -> Peer? {
        peerMap[mcPeerDisplayName]
    }

    private func cancelAllContinuations() {
        for (_, continuation) in messageContinuations {
            continuation.resume(throwing: P2PError.disconnected)
        }
        messageContinuations.removeAll()
    }

    fileprivate func handleReceivedData(_ data: Data, from mcPeer: MCPeerID) {
        guard let envelope = try? JSONDecoder().decode(P2PEnvelope.self, from: data) else { return }

        if envelope.type == .negotiationStart {
            // New incoming negotiation — notify AppState
            onIncomingNegotiation?(envelope)
        } else {
            // Continuation for an existing thread
            if let continuation = messageContinuations.removeValue(forKey: envelope.threadId) {
                continuation.resume(returning: envelope)
            }
        }
    }

    fileprivate func handlePeerConnected(_ mcPeer: MCPeerID, info: [String: String]?) {
        let peerId = mcPeer.displayName
        let username = info?["username"] ?? "Unknown"
        let avatarId = info?["avatarId"] ?? "👤"
        let peer = Peer(id: peerId, username: username, avatarId: avatarId)
        peerMap[peerId] = peer
        mcPeerMap[peerId] = mcPeer
        if !connectedPeers.contains(where: { $0.id == peerId }) {
            connectedPeers.append(peer)
        }
    }

    fileprivate func handlePeerDisconnected(_ mcPeer: MCPeerID) {
        let peerId = mcPeer.displayName
        peerMap.removeValue(forKey: peerId)
        mcPeerMap.removeValue(forKey: peerId)
        connectedPeers.removeAll { $0.id == peerId }
    }

    // Store discovery info from browsing so we can use it when the peer connects
    fileprivate var discoveredPeerInfo: [String: [String: String]] = [:]

    enum P2PError: LocalizedError {
        case peerNotConnected
        case timeout
        case disconnected

        var errorDescription: String? {
            switch self {
            case .peerNotConnected: return "Peer is not connected"
            case .timeout: return "Timed out waiting for response"
            case .disconnected: return "Peer disconnected"
            }
        }
    }
}

// MARK: - MC Delegate Bridge

// NSObject subclass that acts as delegate for all MC protocols.
// Bridges callbacks back to P2PService on MainActor.
private class SessionDelegate: NSObject, MCSessionDelegate, MCNearbyServiceBrowserDelegate, MCNearbyServiceAdvertiserDelegate {
    private weak var service: P2PService?

    init(service: P2PService) {
        self.service = service
    }

    // MARK: MCSessionDelegate

    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        Task { @MainActor in
            guard let service else { return }
            switch state {
            case .connected:
                let info = service.discoveredPeerInfo[peerID.displayName]
                service.handlePeerConnected(peerID, info: info)
            case .notConnected:
                service.handlePeerDisconnected(peerID)
            case .connecting:
                break
            @unknown default:
                break
            }
        }
    }

    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        Task { @MainActor in
            service?.handleReceivedData(data, from: peerID)
        }
    }

    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}

    // MARK: MCNearbyServiceBrowserDelegate

    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        Task { @MainActor in
            guard let service else { return }
            // Store discovery info for when the peer connects
            if let info {
                service.discoveredPeerInfo[peerID.displayName] = info
            }
            // Auto-invite (V0 simplicity)
            browser.invitePeer(peerID, to: service.session, withContext: nil, timeout: 30)
        }
    }

    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        Task { @MainActor in
            service?.discoveredPeerInfo.removeValue(forKey: peerID.displayName)
        }
    }

    // MARK: MCNearbyServiceAdvertiserDelegate

    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        Task { @MainActor in
            // Auto-accept (V0 simplicity)
            invitationHandler(true, service?.session)
        }
    }
}
