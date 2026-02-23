import SwiftUI

struct UseCasesView: View {
    let onNext: () -> Void
    @State private var currentPage = 0

    private let useCases: [(emoji: String, title: String, subtitle: String, description: String, color: Color)] = [
        (
            "📅",
            "Book Anything",
            "Your agent handles scheduling",
            "\"Book my nails for Saturday\" — your agent finds available slots, negotiates with businesses, and books appointments for you.",
            .blue
        ),
        (
            "🛒",
            "Buy & Sell",
            "Your own personal marketplace",
            "\"I'm selling my vintage lamp for €15\" — list items, and when someone's looking, your agents negotiate the deal.",
            .orange
        ),
        (
            "👋",
            "Meet People",
            "Find someone interesting",
            "\"Find someone who loves hiking\" — discover people nearby or through contacts. Your agent breaks the ice so you don't have to.",
            .pink
        ),
        (
            "🏸",
            "Play Sports",
            "Never play alone again",
            "\"Find someone to play squash this evening\" — your agent checks who's available, matches schedules, and sets it up.",
            .green
        ),
        (
            "🏠",
            "Find an Apartment",
            "Your agent hunts for you",
            "\"Find me a 2BR in the 11th under €1500\" — your agent scans listings, filters by your criteria, and alerts you to matches.",
            .purple
        ),
        (
            "👥",
            "Clubs & Communities",
            "Like subreddits, but local",
            "Running clubs, book clubs, whatever — see photos from their meetups and your agent recommends groups that match your vibe.",
            .teal
        ),
        (
            "🎉",
            "Discover Events",
            "Never miss what matters",
            "\"Any AI meetups in Paris this week?\" — your agent finds events on Luma, Meetup, and more, tailored to your interests.",
            .indigo
        ),
    ]

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Title
            VStack(spacing: 8) {
                Text("Your AI Agent")
                    .font(.largeTitle.bold())
                Text("One agent. Endless possibilities.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, 32)

            // Pager
            TabView(selection: $currentPage) {
                ForEach(Array(useCases.enumerated()), id: \.offset) { index, useCase in
                    UseCaseCard(
                        emoji: useCase.emoji,
                        title: useCase.title,
                        subtitle: useCase.subtitle,
                        description: useCase.description,
                        accentColor: useCase.color
                    )
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .frame(height: 320)

            Spacer()

            Button("Get Started") {
                onNext()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.bottom, 40)
        }
    }
}

// MARK: - Use Case Card

struct UseCaseCard: View {
    let emoji: String
    let title: String
    let subtitle: String
    let description: String
    let accentColor: Color

    var body: some View {
        VStack(spacing: 16) {
            Text(emoji)
                .font(.system(size: 56))

            Text(title)
                .font(.title2.bold())

            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(accentColor)
                .fontWeight(.medium)

            Text(description)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(4)
        }
        .padding(.horizontal, 32)
    }
}
