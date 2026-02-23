# V0 Spec — Local-Only Prototype

## Goal

Prove the core UX feels right: **"I chat with my agent, it talks to another agent, I see what happened."**

V0 is LOCAL ONLY — no server, no auth, no Firebase. Just an iOS app calling the Claude API directly. One device, one user, simulated contacts.

---

## What V0 Proves

- Chatting with your own AI agent feels natural and useful
- Asking your agent to coordinate with someone else's agent works as a UX pattern
- Watching a simulated negotiation between two agents feels realistic
- A self-evolving agent personality makes the experience feel personal over time
- The tab-based navigation (Chat / Contacts / Activity / Settings) makes sense

---

## How It Works

### Single Device, Single User

- No authentication — the app stores your profile locally (UserDefaults or a local JSON file)
- No backend — all Claude API calls happen directly from the iOS app via `URLSession`
- No real contacts — friends are hardcoded fake profiles with preset personas

### Your Agent

You chat with your agent in a full-screen chat interface. Every message you send is a direct Claude API call with your agent's evolving system prompt as context. The agent responds conversationally and can take actions (like contacting another agent).

### Simulated Agent-to-Agent

When your agent needs to talk to "Francescu's agent", there is no real Francescu. The app creates a simulated agent with Francescu's fake persona and runs the negotiation locally by alternating Claude API calls:

1. Your agent sends a proposal (Claude call with your system prompt + goal)
2. Francescu's agent responds (Claude call with Francescu's fake persona + the proposal)
3. Back and forth for 2-3 rounds until agreement or failure

The result appears in the Activity tab as a readable conversation thread.

### Self-Evolving Prompt

After each chat session, the app makes one more Claude API call: "Analyze this conversation. What new preferences or facts did you learn about the user?" The response is used to update the agent's system prompt, which is stored locally. Over time, the agent genuinely learns about you.

---

## Onboarding (3 Screens)

### Screen 1 — Pick Your Profile Pic

- Grid of preset avatar images
- Tap to select, highlight selected
- "Next" button

### Screen 2 — Choose Your Username

- Text field for username input
- Local validation only (not empty, reasonable length)
- No uniqueness check (local-only, no server)
- "Next" button

### Screen 3 — Done

- "Your agent is ready."
- Shows your selected avatar and username
- "Start chatting" button → drops into main app (Chat tab)
- Hardcoded fake friends are pre-loaded automatically

---

## Main App (Tab Bar)

### Tab 1 — Chat

Your 1:1 conversation with your agent.

- Full-screen chat interface with message bubbles
- Agent's profile pic and username displayed at the top
- Text input field at the bottom
- Messages persist locally across app sessions
- Every user message triggers a Claude API call
- Agent can respond conversationally AND trigger agent-to-agent threads

**Example interaction:**
```
You: Ask Francescu about squash tomorrow
Agent: Sure! I'll reach out to Francescu's agent about squash tomorrow.
       What time works best for you?
You: Evening, after 6pm
Agent: Got it. I'll propose tomorrow evening after 6pm.
       I'm contacting Francescu's agent now...
Agent: Done! Francescu's agent confirmed — squash tomorrow at 6:30pm
       at the usual court. You can see the full conversation in Activity.
```

### Tab 2 — Contacts

Hardcoded fake friends list.

- List of preset contacts with avatar and name
- Each contact has a hidden persona (used to simulate their agent)
- Tap a contact → option to ask your agent to reach out to them
- Tapping "Reach out" prepopulates a message in the Chat tab

**Hardcoded contacts:**

| Name | Persona |
|---|---|
| Francescu | Loves squash, busy on weekday mornings, prefers evenings. Enthusiastic and quick to say yes to sports. |
| Maria | Foodie, prefers weekends for socializing. Organized planner, suggests restaurants. |
| Luca | Night owl, works late. Hard to pin down but always up for last-minute plans. |
| Sofia | Yoga instructor, early riser. Prefers morning activities, very health-conscious. |
| Marco | Tech nerd, flexible schedule. Always suggests trying new places. Responds fast. |

### Tab 3 — Activity

Read-only feed of agent-to-agent conversation threads.

- List of threads, each showing: contact name, goal, status, timestamp
- Tap a thread → full conversation view (read-only)
- Statuses: Negotiating, Agreed, Failed
- New threads appear here whenever your agent contacts another agent

**Thread list item:**
```
[Avatar] Francescu
"Squash tomorrow evening"
Status: Agreed ✓
2 minutes ago
```

**Thread detail view:**
```
Goal: Schedule squash with Francescu tomorrow evening after 6pm

Your agent: Hi! My user wants to play squash tomorrow evening,
           ideally after 6pm. Does that work for Francescu?

Francescu's agent: Francescu loves squash! Tomorrow evening works.
                   How about 6:30pm at the usual court?

Your agent: 6:30pm works perfectly. Confirmed!

Status: Agreed
Result: Squash with Francescu, tomorrow 6:30pm
```

### Tab 4 — Settings

- **Profile pic**: tap to change (same preset grid as onboarding)
- **Username**: displayed but not editable (set during onboarding)
- **Agent personality**: full text view of the agent's current system prompt. Viewable and editable. Shows how the prompt has evolved over time.

---

## Self-Evolving Prompt — Detail

### Initial Prompt

```
You are a helpful personal AI assistant for {username}. You help your user
coordinate with friends, manage their schedule, and handle social logistics.
You communicate naturally and conversationally. When your user asks you to
reach out to someone, you'll coordinate with that person's agent on their behalf.
```

### Evolution Process

After each chat session (defined as: user closes the app, switches tabs, or after 5 minutes of inactivity):

1. App collects the recent chat messages
2. Makes a Claude API call:
   ```
   System: You are an assistant that analyzes conversations to learn about a user.

   Prompt: Analyze this conversation between a user and their AI assistant.
   What new preferences, habits, or facts did you learn about the user?

   Current personality prompt:
   [existing system prompt]

   Recent conversation:
   [messages]

   Return an updated version of the personality prompt that incorporates
   any new learnings. Keep it concise and factual. Only add information
   that is clearly stated or strongly implied. Do not remove existing facts
   unless contradicted.
   ```
3. The returned prompt replaces the stored system prompt
4. Next chat session uses the updated prompt

### Example Evolution

After a few days of use:

```
You are a helpful personal AI assistant for Filippo. You help your user
coordinate with friends, manage their schedule, and handle social logistics.
You communicate naturally and conversationally.

What you know about Filippo:
- Prefers evenings for sports and social activities (after 6pm)
- Plays squash regularly with Francescu
- Casual communication style, uses humor
- Prefers weekends for dinners and group plans
- Usually free on Tuesday and Thursday evenings
- Likes trying new restaurants but has a few favorites
- Doesn't like making phone calls — prefers text-based coordination
```

---

## Agent-to-Agent Simulation — Detail

### Trigger

The agent-to-agent flow is triggered when the user's agent decides it needs to contact another agent. This happens within the normal chat flow — the Claude API response will indicate intent to contact someone.

### Detection

The app detects the intent by instructing Claude (in the system prompt) to use a structured format when it wants to initiate contact:

```
When you need to contact another person's agent, respond with your
conversational message to the user AND include a structured action block:

[CONTACT_AGENT]
target: {contact_name}
goal: {what you're trying to achieve}
context: {relevant details from the conversation}
[/CONTACT_AGENT]
```

The app parses this block, strips it from the displayed message, and triggers the simulation.

### Simulation Loop

```
Input: target contact name, goal, context from user conversation

1. Look up contact's persona from hardcoded list
2. Build YOUR agent's prompt:
   - System: user's evolving systemPrompt
   - Add context: "You are now negotiating with {target}'s agent.
     Goal: {goal}. Context: {context}.
     Communicate naturally as one AI agent to another.
     Be concise and goal-oriented."

3. Build TARGET agent's prompt:
   - System: "You are an AI agent representing {target}.
     {target's persona description}.
     You are negotiating with another person's agent.
     Respond based on your user's known preferences and availability.
     Be helpful but realistic — don't agree to everything."

4. Loop (max 3 rounds):
   a. Call Claude as YOUR agent → generates proposal/response
   b. Call Claude as TARGET agent → generates counter/acceptance/rejection
   c. Check if resolution reached (agreed/failed)
   d. If not, continue loop

5. Final call to YOUR agent:
   "Summarize the outcome of this negotiation in one sentence."

6. Store thread in local data:
   {targetName, goal, status, messages[], result, timestamp}

7. Update Chat tab:
   Agent sends a message to the user with the outcome
```

### Round Limit

Maximum 3 rounds of back-and-forth. If no agreement after 3 rounds, the thread status is set to "Failed" and the agent reports back to the user with what happened.

---

## V0 Data Model

All data stored locally on device (UserDefaults or a JSON file in the app's documents directory).

```
Local Storage
│
├── myProfile
│   ├── username: String
│   ├── avatarId: String
│   └── systemPrompt: String (self-evolving)
│
├── fakeContacts: [Contact]
│   ├── Contact
│   │   ├── id: String
│   │   ├── name: String
│   │   ├── avatarId: String
│   │   └── persona: String (hidden, used for simulation)
│   │
│   ├── {name: "Francescu", avatarId: "avatar_01",
│   │    persona: "Loves squash, busy on weekday mornings,
│   │    prefers evenings. Enthusiastic about sports."}
│   │
│   ├── {name: "Maria", avatarId: "avatar_02",
│   │    persona: "Foodie, prefers weekends for socializing.
│   │    Organized, suggests restaurants."}
│   │
│   ├── {name: "Luca", avatarId: "avatar_03",
│   │    persona: "Night owl, works late. Hard to pin down
│   │    but up for last-minute plans."}
│   │
│   ├── {name: "Sofia", avatarId: "avatar_04",
│   │    persona: "Yoga instructor, early riser. Prefers
│   │    morning activities, health-conscious."}
│   │
│   └── {name: "Marco", avatarId: "avatar_05",
│        persona: "Tech nerd, flexible schedule. Suggests
│        new places. Responds fast."}
│
├── chatMessages: [ChatMessage]
│   └── ChatMessage
│       ├── id: UUID
│       ├── role: "user" | "agent"
│       ├── content: String
│       └── timestamp: Date
│
└── threads: [Thread]
    └── Thread
        ├── id: UUID
        ├── targetContactId: String
        ├── targetName: String
        ├── goal: String
        ├── status: "negotiating" | "agreed" | "failed"
        ├── messages: [ThreadMessage]
        │   └── ThreadMessage
        │       ├── sender: "my_agent" | "their_agent"
        │       ├── content: String
        │       └── timestamp: Date
        ├── result: String? (summary of outcome)
        └── createdAt: Date
```

---

## API Calls

All API calls go directly from the iOS app to the Claude API via `URLSession`. No backend, no proxy.

### 1. Chat with Your Agent

```
POST https://api.anthropic.com/v1/messages

Headers:
  x-api-key: {API_KEY}
  anthropic-version: 2023-06-01
  content-type: application/json

Body:
{
  "model": "claude-sonnet-4-5-20250929",
  "max_tokens": 1024,
  "system": "{user's evolving systemPrompt}",
  "messages": [
    // chat history (last N messages for context window management)
    {"role": "user", "content": "Ask Francescu about squash tomorrow"},
  ]
}
```

### 2. Agent-to-Agent Negotiation (Simulated)

Alternating calls. Each round = 2 API calls.

**Your agent's turn:**
```
{
  "model": "claude-sonnet-4-5-20250929",
  "max_tokens": 512,
  "system": "{user's systemPrompt}\n\nYou are now negotiating with {target}'s agent. Goal: {goal}. Be concise.",
  "messages": [
    // negotiation history so far
    {"role": "user", "content": "{target agent's last message}"}
  ]
}
```

**Target agent's turn:**
```
{
  "model": "claude-sonnet-4-5-20250929",
  "max_tokens": 512,
  "system": "You are an AI agent for {target}. {target's persona}. Respond realistically.",
  "messages": [
    // negotiation history so far
    {"role": "user", "content": "{your agent's last message}"}
  ]
}
```

### 3. Prompt Evolution

```
{
  "model": "claude-sonnet-4-5-20250929",
  "max_tokens": 1024,
  "system": "You analyze conversations to learn about a user. Be concise and factual.",
  "messages": [
    {"role": "user", "content": "Analyze this conversation...\n\nCurrent prompt:\n{existing prompt}\n\nRecent conversation:\n{messages}\n\nReturn the updated prompt."}
  ]
}
```

### API Cost Estimate (Per Session)

| Action | Calls | Est. tokens | Est. cost |
|---|---|---|---|
| Chat messages (10 messages) | 10 | ~15K | ~$0.05 |
| Agent-to-agent (3 rounds) | 6 | ~5K | ~$0.02 |
| Prompt evolution | 1 | ~2K | ~$0.01 |
| **Typical session** | **~17** | **~22K** | **~$0.08** |

---

## Tech Stack

| Component | Technology |
|---|---|
| **Platform** | iOS 17+, iPhone only |
| **UI** | SwiftUI |
| **Networking** | URLSession (direct Claude API calls) |
| **LLM** | Claude API (claude-sonnet-4-5-20250929) |
| **Local storage** | UserDefaults or JSON file in app documents |
| **Dependencies** | None (no CocoaPods, no SPM packages needed) |

---

## What's IN V0

| Feature | Details |
|---|---|
| Onboarding | 3 screens: avatar, username, done |
| Chat with agent | Full chat interface, Claude API |
| Self-evolving prompt | Learns from conversations, stored locally |
| Simulated agent-to-agent | Fake contacts, local negotiation simulation |
| Activity tab | Read-only view of agent-to-agent threads |
| Contacts tab | Hardcoded fake friends with avatars |
| Settings | Edit avatar, view/edit personality prompt |

## What's OUT of V0

| Feature | Why it's deferred |
|---|---|
| Real auth (phone/Apple Sign-In) | Needs backend |
| Firebase / any backend | V0 is local-only |
| Real contacts sync | Needs backend + permissions |
| Real multi-user | Needs backend |
| Push notifications | Needs backend |
| Business agents | Needs directory, backend |
| Calendar integration | Adds complexity, not core UX |
| Polished UI / animations | Functional first, pretty later |
| Image upload for avatar | Preset grid is sufficient |

---

## Screens Summary

```
Onboarding:
┌─────────────┐   ┌─────────────┐   ┌─────────────┐
│  Pick Avatar │ → │  Username   │ → │    Done!    │
│  (grid)      │   │  (text)     │   │  (start)    │
└─────────────┘   └─────────────┘   └─────────────┘

Main App:
┌─────────────────────────────────────────┐
│  [Agent Avatar] Agent Name              │
│─────────────────────────────────────────│
│                                         │
│  Chat messages...                       │
│                                         │
│  You: Ask Francescu about squash        │
│  Agent: Sure! I'll reach out...         │
│  Agent: Francescu confirmed 6:30pm!     │
│                                         │
│─────────────────────────────────────────│
│  [Type a message...]            [Send]  │
│─────────────────────────────────────────│
│  Chat | Contacts | Activity | Settings  │
└─────────────────────────────────────────┘
```

---

## V0 Success Criteria

- [ ] I can create my agent (pick avatar + choose username)
- [ ] I can chat with my agent naturally and get useful responses
- [ ] I can say "ask Francescu about squash tomorrow" and the agent understands
- [ ] A simulated negotiation runs between my agent and Francescu's agent
- [ ] The negotiation conversation feels realistic (agents actually negotiate, not just agree)
- [ ] I can view the agent-to-agent conversation in the Activity tab
- [ ] My agent remembers things about me across conversations (evolving prompt works)
- [ ] I can view and edit my agent's personality in Settings
- [ ] The tab navigation feels intuitive
- [ ] The whole experience feels like the right UX for the concept
