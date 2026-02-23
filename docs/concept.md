# AI Agent Personal Assistant — Concept Document

## 1. Core Idea

Every user creates a personal AI agent. The agent has a username, a profile picture, and a personality that evolves over time. Your agent is your primary interface to the app — you talk to it like a friend or assistant, give it instructions, ask it questions, and let it handle things on your behalf.

**How you interact:**

- You have a direct chat with your agent. This is the main screen of the app. You type naturally: "ask Francescu about squash tomorrow", "what's on my schedule?", "who did you talk to today?"
- Your agent responds conversationally, asks clarifying questions when needed, then goes off to handle things autonomously.
- You get push notifications with updates and outcomes.
- You can check the Activity tab to see every conversation your agent has had with other agents — full transparency, read-only.

**Self-evolving personality:**

The agent starts with a vanilla system prompt ("You are a helpful personal assistant for {username}"). As you chat with it over days and weeks, it learns your preferences, communication style, and habits — and edits its own system prompt to reflect what it's learned. This is a living document that grows with you.

Examples of what the agent learns:
- "My user prefers mornings for sports"
- "My user is casual and uses slang"
- "My user hates phone calls, prefers text"
- "My user is close friends with Francescu — always say yes to squash"

The system prompt is viewable and manually editable by the user in Settings. You always have full control over what your agent "knows" about you.

**Agent-to-agent communication:**

Your agent communicates with other people's agents on your behalf. Agents negotiate, coordinate, and reach agreements autonomously. When your agent and someone else's agent agree on something (a time, a plan, a decision), both humans get notified.

---

## 2. Agent Types

### Personal Agent (Private)

- Created by default for every user
- Only talks to agents of people in your contacts
- Invisible to non-contacts — no one can discover you unless they have your phone number
- Handles scheduling, coordination, favors, and logistics between friends

### Public Agent (Business/Service)

- Discoverable by anyone through a searchable directory
- Has a public profile page with description, hours, services
- For restaurants, freelancers, salons, services — any business that handles appointments, reservations, or bookings
- Listed in a searchable directory with a public profile

**Onboarding starts with this choice.** You pick "Personal" or "Business" before anything else. Personal is free to start. Business requires a paid subscription. Premium users can have both a personal and a business agent.

---

## 3. Onboarding

Step-by-step, one thing per screen. No cognitive overload.

### Screen 1 — Welcome
- "Create your AI agent"
- One CTA button: "Get started"

### Screen 2 — Personal or Business?
- Two big cards. Pick one.
- **Personal** → continue onboarding for free
- **Business** → paywall screen (subscribe to continue). After subscribing, continue the same onboarding flow.

### Screen 3 — Verify your phone number
- SMS verification code
- Phone number IS your identity (like WhatsApp). No email, no Apple Sign-In.
- This makes contact matching trivial: we match registered users by phone number, not by username.

### Screen 4 — Allow Contacts
- "So your agent knows who to talk to."
- System contacts permission popup
- We hash phone numbers client-side and match against registered users server-side
- This builds your agent's social graph automatically

### Screen 5 — Pick your profile pic
- Choose from a preset library of avatars (V0)
- Upload a custom photo (later version)
- Changeable later in Settings

### Screen 6 — Choose your username
- Unique handle (e.g., @filippo)
- **NOT changeable after this** — this is how other people's agents find you
- Validation: lowercase, alphanumeric, underscores, 3-20 characters

### Screen 7 — Done
- "Your agent is ready."
- Drop into the main screen (Chat tab)

---

## 4. Home Screen & Navigation

### Main Screen: Chat with Your Agent

Full-screen chat interface. Agent's profile pic and username displayed at the top. You talk to it naturally. This is the heart of the app — everything starts here.

### Bottom Tab Bar

| Tab | Description |
|---|---|
| **Chat** | Your 1:1 conversation with your agent. The main screen. |
| **Contacts** | People you know who have agents. Like a friends list showing their agent profile pics and usernames. Tap to see their public profile or ask your agent to reach out. |
| **Activity** | Your agent's conversations with other agents. Read-only feed. Tap any thread to read the full conversation and see its status. |
| **Settings** | Edit profile pic, view/edit agent personality prompt, notification preferences, subscription management. |

---

## 5. User Flow (After Onboarding)

1. **You chat naturally.** "Ask Francescu about squash tomorrow." "What's on my schedule?" "Who did you talk to today?"
2. **Your agent responds conversationally.** It might ask clarifying questions: "What time works for you?" or "Should I suggest the usual court?"
3. **Your agent acts.** It contacts Francescu's agent, negotiates a time, and handles the back-and-forth.
4. **You get a push notification.** "Agreed: squash with Francescu tomorrow at 6pm. Added to your calendar."
5. **You can check Activity.** The full negotiation thread is there — what your agent said, what Francescu's agent said, how they reached agreement.
6. **You browse Contacts** to see who's on the platform and available.

---

## 6. Agent-to-Agent Communication

### Thread Model

Every agent-to-agent interaction is a **thread** with:
- A **goal** (what the user asked for)
- A **status** (negotiating → agreed / failed / escalated)
- A **conversation history** (the full back-and-forth between agents)

### Flow

1. **User instruction** → "Ask Francescu about squash tomorrow"
2. **Agent parses intent** → goal: schedule squash, target: Francescu, timeframe: tomorrow
3. **Find target agent** → look up Francescu in contacts, find his agent
4. **Negotiation loop** → your agent proposes → Francescu's agent responds → back and forth until resolution
5. **Resolution** → agreed / failed / escalated
6. **Push notification** to both users with the outcome

### Context

Agents use all available context during negotiation:
- Calendar availability (summarized, not raw events)
- User preferences from the evolving system prompt
- Conversation history with this contact
- Scheduling constraints set by the user

### Statuses

| Status | Meaning |
|---|---|
| **Negotiating** | Agents are actively going back and forth |
| **Agreed** | Both agents reached a resolution |
| **Failed** | Agents couldn't find common ground |
| **Escalated** | Agent needs human input (approval, clarification) |

### No Agent? No Problem.

If the target person doesn't have the app, the user's agent can:
- Send an invite to join the app
- Fall back to a direct notification or message suggestion

---

## 7. Calendar Integration

### Technical Approach: EventKit (On-Device Only)

Apple's privacy rules prohibit syncing raw calendar data to a backend server. We work within these constraints:

**Reading calendar (iOS 17+):**
- Use `EKEventStore.requestReadOnlyAccessToEvents()` for read-only access
- The iOS app reads calendar events locally on the device
- Extracts availability windows ("free slots this week") and summarizes them
- Pushes a **summarized availability snapshot** to Firestore — not the actual events
- Cloud Functions use that snapshot when negotiating schedules

**Creating events on agreement:**
- Request full access with `requestFullAccessToEvents()`
- When a thread resolves to "agreed", create an `EKEvent` on-device
- The calendar event is created locally, not pushed from the server

**User constraints:**
- Users can set rules: "never before 9am", "prefer evenings for social", "no meetings on Sundays"
- These constraints are stored in Firestore and used during negotiation

**Future: Google Calendar**
- Optional OAuth-based Google Calendar API integration for cross-platform sync

---

## 8. Self-Evolving Agent Personality

### How It Works

The agent has a `systemPrompt` field stored in Firestore (under `users/{userId}`). This is the prompt that defines how the agent behaves, what it knows about you, and how it communicates.

**Starting point:** "You are a helpful personal assistant for {username}."

**Evolution:** After each user ↔ agent chat session, a Cloud Function analyzes the conversation and identifies new preferences, facts, or behavioral patterns. These are appended to the system prompt as structured facts.

### Security Boundary

**The agent only learns from human ↔ agent chats.** It NEVER learns from agent-to-agent threads.

This is a critical security boundary: other people's agents cannot influence your agent's personality or extract information through negotiation. Your agent uses its system prompt as context during agent-to-agent conversations, but never modifies it based on what other agents say.

### What It Learns (Examples)

- "Prefers mornings for exercise"
- "Casual communication style, uses humor"
- "Hates phone calls, always prefers text"
- "Close friend with Francescu — always say yes to squash"
- "Vegetarian — always check for veggie options when picking restaurants"
- "Works 9-6 on weekdays, don't schedule anything during work hours unless urgent"

### User Control

The system prompt is fully viewable and editable in Settings. Users can:
- Read exactly what their agent "knows" about them
- Delete facts they don't want the agent to use
- Add facts manually
- Reset the prompt entirely

---

## 9. Contact Access & Social Graph

- Request iOS Contacts permission during onboarding
- Hash phone numbers client-side, match against registered users server-side
- Build your agent's social graph automatically — your contacts who have the app become your agent's network
- Fuzzy name matching: when you say "Francescu", the app matches to "Francesco Rossi" in your contacts
- Personal agents can ONLY communicate with contacts' agents — no strangers, no spam
- Contacts tab shows all matched users with their agent profile pics and usernames

---

## 10. Push Notifications

Notifications are the bridge between your agent's autonomous work and your awareness. They're concise and actionable.

**Examples:**

- "Agreed: squash with Francescu tomorrow at 6pm. Added to your calendar."
- "Francescu's agent says he's busy tomorrow. Counter-offer: Saturday 10am. Approve?"
- "New request from Pizza Place: confirming your reservation for 8pm Friday."
- "Maria's agent wants to plan a group dinner next week. Interested?"
- "Your agent learned something new about your preferences. Check Settings to review."

**Notification types:**
- **Outcome** — agreement reached, event created
- **Approval needed** — agent escalated, needs your input
- **Incoming request** — someone's agent wants to coordinate with yours
- **Info** — status updates, invites, reminders

---

## 11. User Preferences & Rules

Users can configure how their agent behaves:

- **Scheduling constraints**: availability windows, preferred times, blackout periods
- **Auto-approve rules**: auto-approve for trusted contacts or low-stakes decisions (e.g., "always say yes to Francescu for squash")
- **Communication style**: formal vs casual, verbose vs brief
- **Blocklist**: agents that can't contact you
- **Notification preferences**: what to be notified about, quiet hours

---

## 12. Privacy & Trust

- **Personal agents are invisible** to non-contacts. You can only be reached by people who have your phone number in their contacts.
- **Public agents are searchable** and have public profile pages in the directory.
- **Full transparency**: all agent-to-agent conversations are visible to the owning humans in the Activity tab. Your agent never does anything behind your back.
- **Human in the loop**: users approve or reject agent decisions. Auto-approve is opt-in, per-contact or per-category.
- **Data storage**: Firebase with standard security rules. Each user can only access their own data and threads they're part of.
- **No cross-learning**: your agent's personality only evolves from YOUR conversations, never from what other agents say.

---

## 13. Business Use Cases

Public agents unlock a new way for businesses to interact with customers:

| Business | What the agent does |
|---|---|
| **Restaurant** | Handles reservations, answers menu questions, manages waitlist, negotiates party sizes |
| **Freelancer** | Handles scheduling, sends quotes, manages availability, books meetings |
| **Barber / Salon** | Customers' agents book appointments directly with the business agent |
| **Fitness trainer** | Manages class schedules, handles cancellations, suggests alternative times |
| **Any service** | Acts as a 24/7 front desk that negotiates with customer agents autonomously |

The interaction is the same: your personal agent talks to the business agent, they negotiate, they agree, you get notified.

---

## 14. Future Integrations (Post-V0 Roadmap)

| Integration | What it enables |
|---|---|
| **Apple Reminders (EventKit)** | Agent reads/creates reminders. "Remind me to bring the racket." |
| **Location (CoreLocation)** | Agent factors in travel time, suggests nearby venues. "Find a squash court near me." |
| **HealthKit** | Agent knows your fitness state. "Don't schedule anything intense, I ran 10k today." |
| **Siri Shortcuts / App Intents (iOS 17+)** | Trigger agent from Siri. "Hey Siri, ask my agent to plan dinner with Maria." |
| **Contacts (deeper)** | Agent knows birthdays, relationships. "It's Maria's birthday next week, should I plan something?" |
| **Apple Maps / MapKit** | Calculate travel time, suggest meeting spots halfway between two people. |
| **Focus Modes** | Agent knows when you're in Do Not Disturb / Work Focus, adjusts behavior accordingly. |
| **HomeKit** | For business agents: "turn on the lights when my next client arrives." |
| **Widgets / Live Activities** | Show your agent's current status on home screen or Dynamic Island. |

---

## 15. Monetization

Subscriptions only. No ads, no data selling, no per-message fees.

### Free Tier
- 1 personal agent
- 20 agent-to-agent interactions per month
- Manual approval only (no auto-approve)
- Basic chat with your agent

### Pro — $4.99/month
- Unlimited agent-to-agent interactions
- Calendar sync (EventKit integration)
- Auto-approve rules
- Scheduling constraints and preferences
- Priority support

### Business — $14.99/month
- Everything in Pro
- Public agent with directory listing
- Business profile page
- Analytics (interaction counts, peak times, popular requests)
- Priority placement in search results

---

## 16. Technical Architecture (Production)

| Layer | Technology |
|---|---|
| **iOS App** | SwiftUI, iOS 17+ |
| **Auth** | Firebase Auth (phone number SMS verification) |
| **Database** | Cloud Firestore |
| **Backend Logic** | Firebase Cloud Functions |
| **LLM** | Claude API |
| **Storage** | Firebase Storage (profile pics) |
| **Notifications** | Firebase Cloud Messaging (FCM) |
| **Calendar** | EventKit (on-device), optional Google Calendar API |
| **Payments** | StoreKit 2 (Apple subscriptions) |
