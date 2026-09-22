import Charts
import FamilyHubCore
import SwiftUI

/// Streak, level, weekly activity and badges.
struct ProgressScreen: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let streak = model.streak
        let level = model.level
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    streakCard(streak)
                    levelCard(level)
                    weekCard
                    badgesCard
                }
                .padding(16)
            }
            .background(AppBackground())
            .navigationTitle("Progress")
        }
    }

    private func streakCard(_ s: StreakStatus) -> some View {
        VStack(spacing: 12) {
            HStack(alignment: .center, spacing: 16) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(
                        s.current > 0
                            ? AnyShapeStyle(LinearGradient(colors: [.yellow, .orange, .red], startPoint: .top, endPoint: .bottom))
                            : AnyShapeStyle(Color.secondary.opacity(0.4))
                    )
                    .symbolEffect(.bounce, value: s.current)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(s.current)")
                        .font(.system(size: 44, weight: .heavy, design: .rounded))
                        .contentTransition(.numericText())
                    Text("day streak").font(.headline).foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 6) {
                    Label("\(s.freezes)", systemImage: "snowflake")
                        .font(.headline)
                        .foregroundStyle(.cyan)
                        .accessibilityLabel("\(s.freezes) streak freezes")
                    Text("Best: \(s.longest)").font(.caption).foregroundStyle(.secondary)
                }
            }
            Text(streakMessage(s))
                .font(.subheadline)
                .frame(maxWidth: .infinity, alignment: .leading)
            GoalBar(done: s.doneToday, goal: s.goal)
            Text("Each 7-day run earns a ❄️ freeze (up to 2). If you miss a day, a freeze saves your streak automatically.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(18)
        .card()
    }

    private func streakMessage(_ s: StreakStatus) -> String {
        if s.goalMetToday { return "🎉 Today's goal is done. See you tomorrow!" }
        if s.atRisk { return "Text \(s.goal - s.doneToday == 1 ? "one more person" : "\(s.goal - s.doneToday) more people") today to keep your streak alive." }
        return "Text someone today to start a streak."
    }

    private func levelCard(_ level: Level) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                ZStack {
                    Circle().fill(model.theme.gradient)
                    Text("\(level.number)").font(.title2.bold()).foregroundStyle(.white)
                }
                .frame(width: 52, height: 52)
                VStack(alignment: .leading) {
                    Text(level.title).font(.title3.bold())
                    Text("\(level.xp) XP · \(level.toNext) to level \(level.number + 1)")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
            }
            ProgressView(value: level.progress).tint(model.theme.accent)
            Text("Earn 10 XP per text, +5 if it's on time, +15 for reconnecting after 30 days.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(18)
        .card()
    }

    private var weekCard: some View {
        let days = Engagement.activity(log: model.data.log)
        let goal = model.data.preferences.dailyGoal
        return VStack(alignment: .leading, spacing: 10) {
            Text("This week").font(.headline)
            Chart {
                ForEach(days) { d in
                    BarMark(x: .value("Day", d.day, unit: .day), y: .value("Texts", d.count))
                        .foregroundStyle(d.count >= goal ? model.theme.accent : model.theme.accent.opacity(0.35))
                        .cornerRadius(6)
                }
                RuleMark(y: .value("Goal", goal))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    .foregroundStyle(.secondary)
                    .annotation(position: .top, alignment: .leading) {
                        Text("Goal").font(.caption2).foregroundStyle(.secondary)
                    }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { _ in
                    AxisValueLabel(format: .dateTime.weekday(.narrow))
                }
            }
            .chartYAxis { AxisMarks(values: .automatic(desiredCount: 3)) }
            .frame(height: 140)
        }
        .padding(18)
        .card()
    }

    private var badgesCard: some View {
        let earned = model.data.badges
        return VStack(alignment: .leading, spacing: 12) {
            Text("Badges · \(earned.count) of \(Badge.allCases.count)").font(.headline)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: 12)], spacing: 14) {
                ForEach(Badge.allCases, id: \.self) { badge in
                    let got = earned[badge.rawValue] != nil
                    VStack(spacing: 6) {
                        Image(systemName: got ? badge.symbol : "lock.fill")
                            .font(.title2)
                            .foregroundStyle(got ? AnyShapeStyle(.white) : AnyShapeStyle(.secondary))
                            .frame(width: 58, height: 58)
                            .background(
                                got ? AnyShapeStyle(model.theme.gradient) : AnyShapeStyle(Color.secondary.opacity(0.15)),
                                in: Circle()
                            )
                        Text(badge.title).font(.caption.bold()).multilineTextAlignment(.center)
                        Text(badge.detail).font(.caption2).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    }
                    .opacity(got ? 1 : 0.7)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(badge.title), \(got ? "earned" : "locked"): \(badge.detail)")
                }
            }
        }
        .padding(18)
        .card()
    }
}

/// "1 of 2 today" with a filling bar.
struct GoalBar: View {
    @Environment(AppModel.self) private var model
    let done: Int
    let goal: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Today's goal").font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(min(done, goal)) of \(goal)").font(.subheadline.monospacedDigit()).foregroundStyle(.secondary)
            }
            ProgressView(value: Double(min(done, goal)), total: Double(goal))
                .tint(done >= goal ? .green : model.theme.accent)
        }
    }
}
