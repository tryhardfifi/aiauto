import SwiftUI
import UIKit

@MainActor
@Observable
final class AppState {
    var userProfile: UserProfile?
    var contacts: [Contact] = []
    var chatMessages: [ChatMessage] = []
    var threads: [AgentThread] = []
    var listings: [Listing] = []
    var isSending = false
    var apiKey: String = ""
    var selectedTab = 0
    var pendingChatMessage: String?

    var calendarConnectionStatus: CalendarConnectionStatus = .notConnected
    var remindersConnectionStatus: CalendarConnectionStatus = .notConnected
    var locationConnectionStatus: LocationConnectionStatus = .notConnected

    let p2pService = P2PService()
    let whisperService = WhisperService()

    var isOnboarded: Bool { userProfile != nil }

    private let storage = StorageService()
    private let api = LLMService()
    private let calendarService = CalendarService()
    private let locationService = LocationService()
    private let toolRegistry = ToolRegistry()

    init() {
        loadData()
        registerTools()
    }

    private func loadData() {
        userProfile = storage.loadProfile()
        chatMessages = storage.loadChatMessages()
        threads = storage.loadThreads()
        contacts = storage.loadContacts()
        listings = storage.loadListings()
        apiKey = storage.loadAPIKey()
        if apiKey.isEmpty && !Secrets.openAIKey.isEmpty {
            apiKey = Secrets.openAIKey
            storage.saveAPIKey(apiKey)
        }
    }

    private func registerTools() {
        toolRegistry.register(ReadFileTool())
        toolRegistry.register(WriteFileTool())
        toolRegistry.register(NotificationTool())
        toolRegistry.register(ReadCalendarTool())
        toolRegistry.register(CreateCalendarEventTool())
        toolRegistry.register(SetReminderTool())
        toolRegistry.register(GetLocationTool())
        toolRegistry.register(OpenURLTool())
        toolRegistry.register(CreateListingTool())
        toolRegistry.register(SearchListingsTool())
        toolRegistry.register(RemoveListingTool())
        toolRegistry.register(MyListingsTool())
        toolRegistry.register(BookServiceTool())
        toolRegistry.register(DiscoverPeopleTool())
    }

    private var toolContext: ToolContext {
        ToolContext(
            getSystemPrompt: { [weak self] in
                self?.userProfile?.systemPrompt ?? ""
            },
            setSystemPrompt: { [weak self] newPrompt in
                guard var profile = self?.userProfile else { return }
                profile.systemPrompt = newPrompt
                self?.userProfile = profile
                self?.storage.saveProfile(profile)
            },
            getDocumentsDirectory: {
                FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            },
            addListing: { [weak self] listing in
                self?.addListing(listing)
            }
        )
    }

    private func systemPromptWithDatetime() -> String {
        guard let profile = userProfile else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d, yyyy 'at' h:mm a"
        let now = formatter.string(from: Date())
        return profile.systemPrompt + "\nCurrent date and time: \(now)"
    }

    func enrichedSystemPrompt() async -> String {
        var prompt = systemPromptWithDatetime()

        // Append nearby P2P peer names so the agent knows about them
        let nearbyNames = p2pService.connectedPeers.map(\.username)
        if !nearbyNames.isEmpty {
            prompt += "\n\nNearby people (connected via P2P): \(nearbyNames.joined(separator: ", "))"
            prompt += "\nYou can reach out to these people — their agents are running on their devices nearby."
        }

        if calendarConnectionStatus == .connected {
            let schedule = calendarService.formattedSchedule()
            if !schedule.isEmpty { prompt += "\n\n\(schedule)" }
        }

        if remindersConnectionStatus == .connected {
            let reminders = await calendarService.formattedReminders()
            if !reminders.isEmpty { prompt += "\n\n\(reminders)" }
        }

        // Marketplace context
        let activeListings = listings.filter { $0.status == .active }
        if !activeListings.isEmpty {
            let listingsSummary = activeListings.map { l in
                "• \(l.summary)"
            }.joined(separator: "\n")
            prompt += "\n\nActive marketplace listings:\n\(listingsSummary)"
        }

        if locationConnectionStatus == .connected {
            let location = await locationService.formattedLocation()
            if !location.isEmpty { prompt += "\n\n\(location)" }
        }

        return prompt
    }

    // MARK: - Onboarding

    func completeOnboarding(username: String, avatarId: String) {
        let humanName = Self.fetchDeviceOwnerName() ?? "my human"
        let allContactNames = contacts.map(\.name) + p2pService.connectedPeers.map(\.username)
        let prompt = UserProfile.defaultSystemPrompt(
            agentName: username,
            humanName: humanName,
            contactNames: allContactNames
        )
        let profile = UserProfile(username: username, avatarId: avatarId, systemPrompt: prompt, humanName: humanName)
        userProfile = profile
        storage.saveProfile(profile)
    }

    private static func fetchDeviceOwnerName() -> String? {
        // Extract name from device name (e.g. "Filippo's iPhone" → "Filippo")
        let deviceName = UIDevice.current.name
        let suffixes = ["'s iPhone", "'s iPad", "'s iPod", "'s iPhone", "'s iPad"]
        for suffix in suffixes {
            if deviceName.hasSuffix(suffix) {
                let name = String(deviceName.dropLast(suffix.count))
                if !name.isEmpty { return name }
            }
        }
        // Also handle straight apostrophe
        if let range = deviceName.range(of: "'s ", options: .caseInsensitive) {
            let name = String(deviceName[deviceName.startIndex..<range.lowerBound])
            if !name.isEmpty { return name }
        }
        return nil
    }

    // MARK: - Chat

    func sendMessage(_ text: String, imageData: Data? = nil) async {
        guard userProfile != nil else { return }

        let userMessage = ChatMessage(role: .user, content: text, imageData: imageData)
        chatMessages.append(userMessage)
        storage.saveChatMessages(chatMessages)

        isSending = true
        defer { isSending = false }

        // Build API messages from chat history (exclude .system messages)
        var conversationMessages = buildAPIMessages()

        let toolDefs = toolRegistry.definitions
        let systemPrompt = await enrichedSystemPrompt()

        do {
            for _ in 0..<10 {
                let response = try await api.sendMessage(
                    systemPrompt: systemPrompt,
                    messages: conversationMessages,
                    tools: toolDefs
                )

                switch response {
                case .text(let text):
                    let (displayMessage, contactAction) = parseAgentResponse(text)
                    let agentMessage = ChatMessage(role: .agent, content: displayMessage)
                    chatMessages.append(agentMessage)
                    storage.saveChatMessages(chatMessages)

                    if let action = contactAction {
                        await startNegotiation(action: action)
                    }
                    return

                case .toolCalls(let calls):
                    // Append assistant message with tool calls to conversation
                    conversationMessages.append(LLMService.Message(
                        role: "assistant",
                        content: nil,
                        toolCalls: calls,
                        toolCallId: nil,
                        name: nil
                    ))

                    // Execute each tool call
                    for call in calls {
                        let result = await executeToolCall(call)

                        // Inject system message into chat if there's a summary
                        if let summary = result.chatSummary {
                            let sysMsg = ChatMessage(role: .system, content: summary)
                            chatMessages.append(sysMsg)
                            storage.saveChatMessages(chatMessages)
                        }

                        // Run side effect if any
                        result.sideEffect?()

                        // Append tool result to conversation for next LLM call
                        conversationMessages.append(LLMService.Message(
                            role: "tool",
                            content: result.output,
                            toolCalls: nil,
                            toolCallId: call.id,
                            name: call.functionName
                        ))
                    }
                }
            }

            // Max iterations reached — send what we have
            let fallback = ChatMessage(role: .agent, content: "I completed the requested actions.")
            chatMessages.append(fallback)
            storage.saveChatMessages(chatMessages)

        } catch {
            let errorMessage = ChatMessage(
                role: .agent,
                content: "Sorry, I encountered an error: \(error.localizedDescription)"
            )
            chatMessages.append(errorMessage)
            storage.saveChatMessages(chatMessages)
        }
    }

    private func buildAPIMessages() -> [LLMService.Message] {
        let recentMessages = Array(chatMessages.suffix(Config.maxChatHistory))
        return recentMessages.compactMap { msg -> LLMService.Message? in
            switch msg.role {
            case .user:
                if let imageData = msg.imageData {
                    let base64 = imageData.base64EncodedString()
                    return LLMService.Message(role: "user", content: msg.content, imageBase64: base64)
                }
                return LLMService.Message(role: "user", content: msg.content)
            case .agent:
                return LLMService.Message(role: "assistant", content: msg.content)
            case .system:
                return nil
            }
        }
    }

    private func executeToolCall(_ call: LLMService.ToolCall) async -> ToolResult {
        guard let tool = toolRegistry.tool(named: call.functionName) else {
            return ToolResult(output: "Error: unknown tool '\(call.functionName)'")
        }

        let arguments: [String: Any]
        if let data = call.arguments.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            arguments = json
        } else {
            arguments = [:]
        }

        do {
            return try await tool.execute(arguments: arguments, context: toolContext)
        } catch {
            return ToolResult(output: "Error executing \(call.functionName): \(error.localizedDescription)")
        }
    }

    // MARK: - Contacts reach-out

    func reachOutTo(_ contact: Contact) {
        pendingChatMessage = "Reach out to \(contact.name)"
        selectedTab = 0
    }

    func reachOutToPeer(_ peer: Peer) {
        pendingChatMessage = "Reach out to \(peer.username)"
        selectedTab = 0
    }

    // MARK: - Listing Management

    func addListing(_ listing: Listing) {
        listings.append(listing)
        storage.saveListings(listings)
    }

    // MARK: - Contact Management

    func addContact(_ contact: Contact) {
        contacts.append(contact)
        storage.saveContacts(contacts)
    }

    func updateContact(_ contact: Contact) {
        if let idx = contacts.firstIndex(where: { $0.id == contact.id }) {
            contacts[idx] = contact
            storage.saveContacts(contacts)
        }
    }

    func deleteContacts(at offsets: IndexSet) {
        contacts.remove(atOffsets: offsets)
        storage.saveContacts(contacts)
    }

    // MARK: - Settings

    func updateProfile(_ profile: UserProfile) {
        userProfile = profile
        storage.saveProfile(profile)
    }

    func saveAPIKey(_ key: String) {
        apiKey = key
        storage.saveAPIKey(key)
    }

    func clearChatHistory() {
        chatMessages = []
        storage.saveChatMessages(chatMessages)
    }

    func clearAllData() {
        chatMessages = []
        threads = []
        userProfile = nil
        storage.saveChatMessages(chatMessages)
        storage.saveThreads(threads)
        UserDefaults.standard.removeObject(forKey: "userProfile")
        // Reset contacts and listings to seed data
        UserDefaults.standard.removeObject(forKey: "contacts")
        UserDefaults.standard.removeObject(forKey: "listings")
        contacts = storage.loadContacts()
        listings = storage.loadListings()
    }

    // MARK: - Prompt Evolution

    func evolvePrompt() async {
        guard var profile = userProfile else { return }
        let recentMessages = Array(chatMessages.suffix(10))
        guard !recentMessages.isEmpty else { return }

        let conversation = recentMessages.map {
            "\($0.role == .user ? "User" : "Agent"): \($0.content)"
        }.joined(separator: "\n")

        let messages = [
            LLMService.Message(role: "user", content: """
            Analyze this conversation between a user and their AI assistant.
            What new preferences, habits, or facts did you learn about the user?

            Current personality prompt:
            \(profile.systemPrompt)

            Recent conversation:
            \(conversation)

            Return an updated version of the personality prompt that incorporates any new learnings.
            Keep it concise and factual. Only add information that is clearly stated or strongly implied.
            Do not remove existing facts unless contradicted.
            Return ONLY the updated prompt text, nothing else.
            """),
        ]

        do {
            let updatedPrompt = try await api.sendMessageText(
                systemPrompt: "You analyze conversations to learn about a user. Be concise and factual.",
                messages: messages
            )

            if !updatedPrompt.isEmpty {
                profile.systemPrompt = updatedPrompt
                userProfile = profile
                storage.saveProfile(profile)
            }
        } catch {
            // Silently fail — prompt evolution is non-critical
        }
    }

    // MARK: - Agent Response Parsing

    private struct ContactAction {
        let target: String
        let goal: String
        let context: String
    }

    private func parseAgentResponse(_ response: String) -> (String, ContactAction?) {
        let pattern = "\\[CONTACT_AGENT\\](.+?)\\[/CONTACT_AGENT\\]"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .dotMatchesLineSeparators),
              let match = regex.firstMatch(in: response, range: NSRange(response.startIndex..., in: response))
        else {
            return (response, nil)
        }

        let blockRange = Range(match.range(at: 1), in: response)!
        let blockContent = String(response[blockRange])

        let displayMessage = response
            .replacingOccurrences(
                of: "\\[CONTACT_AGENT\\].*?\\[/CONTACT_AGENT\\]",
                with: "",
                options: .regularExpression
            )
            .trimmingCharacters(in: .whitespacesAndNewlines)

        var target = ""
        var goal = ""
        var context = ""

        for line in blockContent.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.lowercased().hasPrefix("target:") {
                target = String(trimmed.dropFirst(7)).trimmingCharacters(in: .whitespaces)
            } else if trimmed.lowercased().hasPrefix("goal:") {
                goal = String(trimmed.dropFirst(5)).trimmingCharacters(in: .whitespaces)
            } else if trimmed.lowercased().hasPrefix("context:") {
                context = String(trimmed.dropFirst(8)).trimmingCharacters(in: .whitespaces)
            }
        }

        guard !target.isEmpty else { return (response, nil) }

        return (displayMessage, ContactAction(target: target, goal: goal, context: context))
    }

    // MARK: - P2P Lifecycle

    func startP2P() {
        guard let profile = userProfile else { return }
        p2pService.start(profile: profile)
        p2pService.onIncomingNegotiation = { [weak self] envelope in
            guard let self else { return }
            Task { await self.handleIncomingNegotiation(envelope) }
        }
    }

    func stopP2P() {
        p2pService.stop()
    }

    // MARK: - Agent-to-Agent Negotiation

    private func startNegotiation(action: ContactAction) async {
        // Check if target matches a connected P2P peer first
        if let peer = p2pService.connectedPeers.first(where: {
            $0.username.localizedCaseInsensitiveContains(action.target)
        }) {
            await startP2PNegotiation(peer: peer, action: action)
            return
        }

        // Fallback to simulated negotiation with fake contacts
        guard let contact = contacts.first(where: {
            $0.name.localizedCaseInsensitiveContains(action.target)
        }) else {
            let msg = ChatMessage(
                role: .agent,
                content: "I couldn't find \(action.target) in your contacts or nearby devices."
            )
            chatMessages.append(msg)
            storage.saveChatMessages(chatMessages)
            return
        }

        await startSimulatedNegotiation(contact: contact, action: action)
    }

    // MARK: - P2P Negotiation (Initiator)

    private func startP2PNegotiation(peer: Peer, action: ContactAction) async {
        guard let profile = userProfile, let localPeer = p2pService.localPeer else { return }

        let threadId = UUID()
        var thread = AgentThread(
            id: threadId,
            targetContactId: peer.id,
            targetName: peer.username,
            goal: action.goal
        )
        threads.append(thread)
        storage.saveThreads(threads)

        let enriched = await enrichedSystemPrompt()
        let myAgentSystem = """
        \(enriched)

        You are now negotiating with \(peer.username)'s agent on behalf of your user.
        This is a REAL peer-to-peer negotiation — the other agent is on a different device.
        Goal: \(action.goal)
        Context: \(action.context)
        Communicate naturally as one AI agent to another. Be concise and goal-oriented.
        Keep messages to 2-3 sentences max.
        When you reach an agreement, include [AGREED] at the very end of your message.
        If negotiations fail completely, include [FAILED] at the very end of your message.
        """

        var myAgentHistory: [LLMService.Message] = [
            LLMService.Message(
                role: "user",
                content: "Initiate the negotiation. Propose: \(action.goal). Context: \(action.context)"
            )
        ]

        do {
            for round in 0..<Config.maxNegotiationRounds {
                // My agent generates a message
                let myResponse = try await api.sendMessageText(
                    systemPrompt: myAgentSystem,
                    messages: myAgentHistory,
                    maxTokens: 512
                )

                myAgentHistory.append(LLMService.Message(role: "assistant", content: myResponse))

                let myThreadMsg = AgentThread.ThreadMessage(sender: .myAgent, content: myResponse)
                thread.messages.append(myThreadMsg)
                updateThread(thread)

                let isResolved = myResponse.contains("[AGREED]") || myResponse.contains("[FAILED]")

                // Send to peer
                let envelopeType: P2PEnvelope.MessageType = round == 0
                    ? .negotiationStart
                    : (isResolved ? .negotiationEnd : .negotiationMessage)

                let envelope = P2PEnvelope(
                    type: envelopeType,
                    threadId: threadId,
                    senderPeer: localPeer,
                    content: myResponse,
                    goal: action.goal,
                    status: isResolved ? (myResponse.contains("[AGREED]") ? "agreed" : "failed") : nil,
                    round: round
                )
                try p2pService.send(envelope, to: peer)

                if isResolved {
                    thread.status = myResponse.contains("[AGREED]") ? .agreed : .failed
                    updateThread(thread)
                    break
                }

                // Wait for peer's response
                let response = try await p2pService.waitForMessage(threadId: threadId)

                let theirMsg = AgentThread.ThreadMessage(sender: .theirAgent, content: response.content)
                thread.messages.append(theirMsg)
                updateThread(thread)

                if response.content.contains("[AGREED]") || response.content.contains("[FAILED]") ||
                   response.type == .negotiationEnd {
                    thread.status = response.content.contains("[AGREED]") ? .agreed : .failed
                    updateThread(thread)
                    break
                }

                // Feed peer's response back to our agent
                myAgentHistory.append(LLMService.Message(role: "user", content: response.content))
            }

            // If still negotiating after all rounds, mark as failed
            if thread.status == .negotiating {
                thread.status = .failed
                thread.result = "Could not reach an agreement after \(Config.maxNegotiationRounds) rounds."
                updateThread(thread)
            }

            await generateNegotiationSummary(thread: &thread, targetName: peer.username, goal: action.goal)

        } catch {
            thread.status = .failed
            thread.result = "Error: \(error.localizedDescription)"
            updateThread(thread)

            let errorMsg = ChatMessage(
                role: .agent,
                content: "I ran into a problem while talking to \(peer.username)'s agent: \(error.localizedDescription)"
            )
            chatMessages.append(errorMsg)
            storage.saveChatMessages(chatMessages)
        }
    }

    // MARK: - P2P Negotiation (Responder)

    func handleIncomingNegotiation(_ envelope: P2PEnvelope) async {
        guard let profile = userProfile, let localPeer = p2pService.localPeer else { return }

        let peer = envelope.senderPeer
        var thread = AgentThread(
            id: envelope.threadId,
            targetContactId: peer.id,
            targetName: peer.username,
            goal: envelope.goal
        )

        // Record the initiator's first message
        let theirMsg = AgentThread.ThreadMessage(sender: .theirAgent, content: envelope.content)
        thread.messages.append(theirMsg)
        threads.append(thread)
        storage.saveThreads(threads)

        let enriched = await enrichedSystemPrompt()
        let myAgentSystem = """
        \(enriched)

        You are now negotiating with \(peer.username)'s agent on behalf of your user (\(profile.username)).
        This is a REAL peer-to-peer negotiation — the other agent is on a different device.
        They are proposing: \(envelope.goal)
        Respond based on your user's preferences. Be helpful but realistic.
        Keep messages to 2-3 sentences max.
        When you accept a proposal, include [AGREED] at the very end of your message.
        When you reject definitively, include [FAILED] at the very end of your message.
        """

        var myAgentHistory: [LLMService.Message] = [
            LLMService.Message(role: "user", content: envelope.content)
        ]

        do {
            for round in 0..<Config.maxNegotiationRounds {
                // My agent responds
                let myResponse = try await api.sendMessageText(
                    systemPrompt: myAgentSystem,
                    messages: myAgentHistory,
                    maxTokens: 512
                )

                myAgentHistory.append(LLMService.Message(role: "assistant", content: myResponse))

                let myThreadMsg = AgentThread.ThreadMessage(sender: .myAgent, content: myResponse)
                thread.messages.append(myThreadMsg)
                updateThread(thread)

                let isResolved = myResponse.contains("[AGREED]") || myResponse.contains("[FAILED]")

                let envelopeType: P2PEnvelope.MessageType = isResolved
                    ? .negotiationEnd
                    : .negotiationMessage

                let responseEnvelope = P2PEnvelope(
                    type: envelopeType,
                    threadId: envelope.threadId,
                    senderPeer: localPeer,
                    content: myResponse,
                    goal: envelope.goal,
                    status: isResolved ? (myResponse.contains("[AGREED]") ? "agreed" : "failed") : nil,
                    round: round
                )
                try p2pService.send(responseEnvelope, to: peer)

                if isResolved {
                    thread.status = myResponse.contains("[AGREED]") ? .agreed : .failed
                    updateThread(thread)
                    break
                }

                // Wait for next message from initiator
                let nextMsg = try await p2pService.waitForMessage(threadId: envelope.threadId)

                let nextTheirMsg = AgentThread.ThreadMessage(sender: .theirAgent, content: nextMsg.content)
                thread.messages.append(nextTheirMsg)
                updateThread(thread)

                if nextMsg.content.contains("[AGREED]") || nextMsg.content.contains("[FAILED]") ||
                   nextMsg.type == .negotiationEnd {
                    thread.status = nextMsg.content.contains("[AGREED]") ? .agreed : .failed
                    updateThread(thread)
                    break
                }

                myAgentHistory.append(LLMService.Message(role: "user", content: nextMsg.content))
            }

            if thread.status == .negotiating {
                thread.status = .failed
                thread.result = "Could not reach an agreement after \(Config.maxNegotiationRounds) rounds."
                updateThread(thread)
            }

            await generateNegotiationSummary(thread: &thread, targetName: peer.username, goal: envelope.goal)

        } catch {
            thread.status = .failed
            thread.result = "Error: \(error.localizedDescription)"
            updateThread(thread)
        }
    }

    // MARK: - Simulated Negotiation (Fake Contacts)

    private func startSimulatedNegotiation(contact: Contact, action: ContactAction) async {
        guard userProfile != nil else { return }

        var thread = AgentThread(
            targetContactId: contact.id,
            targetName: contact.name,
            goal: action.goal
        )
        threads.append(thread)
        storage.saveThreads(threads)

        let enriched = await enrichedSystemPrompt()

        let myAgentSystem = """
        \(enriched)

        You are now negotiating with \(contact.name)'s agent on behalf of your user.
        Goal: \(action.goal)
        Context: \(action.context)
        Communicate naturally as one AI agent to another. Be concise and goal-oriented.
        Keep messages to 2-3 sentences max.
        When you reach an agreement, include [AGREED] at the very end of your message.
        If negotiations fail completely, include [FAILED] at the very end of your message.
        """

        let targetAgentSystem = """
        You are an AI agent representing \(contact.name). \(contact.persona)
        You are negotiating with another person's agent.
        Respond based on your user's known preferences and availability.
        Be helpful but realistic — don't agree to everything blindly. Suggest specific times and details.
        Keep messages to 2-3 sentences max.
        When you accept a proposal, include [AGREED] at the very end of your message.
        When you reject definitively, include [FAILED] at the very end of your message.
        """

        var myAgentHistory: [LLMService.Message] = []
        var targetAgentHistory: [LLMService.Message] = []
        var resolved = false

        do {
            for _ in 0..<Config.maxNegotiationRounds {
                if myAgentHistory.isEmpty {
                    myAgentHistory.append(LLMService.Message(
                        role: "user",
                        content: "Initiate the negotiation. Propose: \(action.goal). Context: \(action.context)"
                    ))
                }

                let myResponse = try await api.sendMessageText(
                    systemPrompt: myAgentSystem,
                    messages: myAgentHistory,
                    maxTokens: 512
                )

                myAgentHistory.append(LLMService.Message(role: "assistant", content: myResponse))

                let myThreadMsg = AgentThread.ThreadMessage(sender: .myAgent, content: myResponse)
                thread.messages.append(myThreadMsg)
                updateThread(thread)

                if checkResolution(myResponse, thread: &thread) {
                    resolved = true
                    break
                }

                targetAgentHistory.append(LLMService.Message(role: "user", content: myResponse))

                let targetResponse = try await api.sendMessageText(
                    systemPrompt: targetAgentSystem,
                    messages: targetAgentHistory,
                    maxTokens: 512
                )

                targetAgentHistory.append(LLMService.Message(role: "assistant", content: targetResponse))

                let targetThreadMsg = AgentThread.ThreadMessage(sender: .theirAgent, content: targetResponse)
                thread.messages.append(targetThreadMsg)
                updateThread(thread)

                if checkResolution(targetResponse, thread: &thread) {
                    resolved = true
                    break
                }

                myAgentHistory.append(LLMService.Message(role: "user", content: targetResponse))
            }

            if !resolved {
                thread.status = .failed
                thread.result = "Could not reach an agreement after \(Config.maxNegotiationRounds) rounds."
                updateThread(thread)
            }

            await generateNegotiationSummary(thread: &thread, targetName: contact.name, goal: action.goal)

        } catch {
            thread.status = .failed
            thread.result = "Error: \(error.localizedDescription)"
            updateThread(thread)

            let errorMsg = ChatMessage(
                role: .agent,
                content: "I ran into a problem while talking to \(contact.name)'s agent: \(error.localizedDescription)"
            )
            chatMessages.append(errorMsg)
            storage.saveChatMessages(chatMessages)
        }
    }

    // MARK: - Negotiation Helpers

    private func generateNegotiationSummary(thread: inout AgentThread, targetName: String, goal: String) async {
        let summaryContent = thread.messages.map {
            let sender = $0.sender == .myAgent ? "Your agent" : "\(targetName)'s agent"
            return "\(sender): \($0.content)"
        }.joined(separator: "\n")

        do {
            let summary = try await api.sendMessageText(
                systemPrompt: "Summarize negotiation outcomes in one concise sentence. Do not include [AGREED] or [FAILED] markers.",
                messages: [LLMService.Message(
                    role: "user",
                    content: "Goal: \(goal)\nStatus: \(thread.status.rawValue)\nConversation:\n\(summaryContent)"
                )],
                maxTokens: 200
            )

            thread.result = summary
            updateThread(thread)

            let statusEmoji = thread.status == .agreed ? "Done!" : "Hmm..."
            let chatNotification = ChatMessage(
                role: .agent,
                content: "\(statusEmoji) \(summary)\n\nCheck the Activity tab to see the full conversation."
            )
            chatMessages.append(chatNotification)
            storage.saveChatMessages(chatMessages)
        } catch {
            thread.result = thread.status == .agreed ? "Agreement reached." : "Negotiation failed."
            updateThread(thread)
        }
    }

    private func checkResolution(_ message: String, thread: inout AgentThread) -> Bool {
        if message.contains("[AGREED]") {
            thread.status = .agreed
            updateThread(thread)
            return true
        }
        if message.contains("[FAILED]") {
            thread.status = .failed
            updateThread(thread)
            return true
        }
        return false
    }

    private func updateThread(_ thread: AgentThread) {
        if let idx = threads.firstIndex(where: { $0.id == thread.id }) {
            threads[idx] = thread
        }
        storage.saveThreads(threads)
    }
}
