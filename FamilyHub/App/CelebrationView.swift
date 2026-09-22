import FamilyHubCore
import SwiftUI

/// Full-screen "nice job" moment after a reach-out: confetti, points, streak and any new badges.
struct CelebrationView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let result: ReachOutResult
    let onDone: () -> Void
    @State private var appeared = false

    var body: some View {
        ZStack {
            model.theme.gradient.ignoresSafeArea()
            if !reduceMotion { ConfettiView().ignoresSafeArea().allowsHitTesting(false) }

            VStack(spacing: 22) {
                Spacer()
                if let person = model.person(result.personID) {
                    Avatar(person: person, size: 96)
                        .overlay(Circle().stroke(.white, lineWidth: 4))
                        .shadow(radius: 10)
                    Text(headline(for: person))
                        .font(.system(.title, design: .rounded).bold())
                        .multilineTextAlignment(.center)
                }

                Text("+\(result.points) XP")
                    .font(.system(size: 44, weight: .heavy, design: .rounded))
                    .scaleEffect(appeared ? 1 : 0.4)
                    .opacity(appeared ? 1 : 0)

                HStack(spacing: 14) {
                    StatPill(symbol: "flame.fill", value: "\(result.streak.current)", label: "day streak")
                    StatPill(symbol: "star.circle.fill", value: "Lv \(result.level.number)", label: result.level.title)
                }

                if result.leveledUp {
                    Label("Level up! You're a \(result.level.title)", systemImage: "arrow.up.circle.fill")
                        .font(.headline)
                        .padding(.horizontal, 16).padding(.vertical, 10)
                        .background(.white.opacity(0.22), in: Capsule())
                }

                ForEach(result.newBadges, id: \.self) { badge in
                    HStack(spacing: 12) {
                        Image(systemName: badge.symbol)
                            .font(.title2)
                            .frame(width: 48, height: 48)
                            .background(.white.opacity(0.25), in: Circle())
                        VStack(alignment: .leading) {
                            Text("New badge: \(badge.title)").font(.headline)
                            Text(badge.detail).font(.subheadline).opacity(0.85)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(12)
                    .background(.white.opacity(0.18), in: RoundedRectangle(cornerRadius: 18))
                }

                Spacer()
                Button(action: onDone) {
                    Text("Keep it up!")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(.white, in: Capsule())
                        .foregroundStyle(model.theme.accent)
                }
            }
            .padding(24)
            .foregroundStyle(.white)
        }
        .sensoryFeedback(.success, trigger: appeared)
        .onAppear {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.55).delay(0.1)) { appeared = true }
        }
    }

    private func headline(for person: Person) -> String {
        switch result.kind {
        case .first: return "First text to \(person.firstName)! 🎉"
        case .reconnect: return "You reconnected with \(person.firstName)! 💛"
        case .onTime: return "Right on time with \(person.firstName)!"
        case .late: return "\(person.firstName) will be glad you did!"
        }
    }
}

private struct StatPill: View {
    let symbol: String
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 2) {
            Label(value, systemImage: symbol).font(.title3.bold())
            Text(label).font(.caption).opacity(0.85)
        }
        .padding(.horizontal, 18).padding(.vertical, 10)
        .background(.white.opacity(0.2), in: RoundedRectangle(cornerRadius: 16))
    }
}

/// Lightweight confetti: a few dozen pieces drawn in one Canvas per frame.
struct ConfettiView: View {
    private struct Piece {
        let x: Double, delay: Double, speed: Double, spin: Double, size: Double, color: Color, sway: Double
    }

    // @State so the pieces keep their paths when the parent re-renders.
    @State private var pieces: [Piece] = (0..<70).map { _ in
        Piece(
            x: .random(in: 0...1), delay: .random(in: 0...0.8), speed: .random(in: 0.25...0.5),
            spin: .random(in: 2...8), size: .random(in: 6...11),
            color: [.yellow, .white, .pink, .orange, .mint, .cyan].randomElement()!, sway: .random(in: 10...40)
        )
    }
    @State private var start = Date.now

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { ctx, size in
                let t = timeline.date.timeIntervalSince(start)
                for p in pieces {
                    let life = t - p.delay
                    guard life > 0 else { continue }
                    let y = -20 + life * p.speed * size.height
                    guard y < size.height + 20 else { continue }
                    let x = p.x * size.width + sin(life * 3 + p.x * 10) * p.sway
                    var c = ctx
                    c.translateBy(x: x, y: y)
                    c.rotate(by: .radians(life * p.spin))
                    c.fill(Path(CGRect(x: -p.size / 2, y: -p.size / 4, width: p.size, height: p.size / 2)), with: .color(p.color))
                }
            }
        }
    }
}
