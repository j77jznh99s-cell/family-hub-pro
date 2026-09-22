import FamilyHubCore
import SwiftUI

@main
struct FamilyHubApp: App {
    @State private var model = AppModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .onOpenURL { model.handle(url: $0) }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active {
                        model.reload()
                        Task { await model.refreshOpenersIfNeeded() }
                    }
                }
        }
    }
}

struct RootView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        TabView(selection: $model.selectedTab) {
            TodayView()
                .tabItem { Label("Today", systemImage: "bubble.left.and.bubble.right.fill") }
                .tag(AppModel.Tab.today)
            FavoritesView()
                .tabItem { Label("Favorites", systemImage: "star.fill") }
                .tag(AppModel.Tab.favorites)
            ProgressScreen()
                .tabItem { Label("Progress", systemImage: "flame.fill") }
                .tag(AppModel.Tab.progress)
            PeopleView()
                .tabItem { Label("People", systemImage: "person.2.fill") }
                .tag(AppModel.Tab.people)
            AboutMeView()
                .tabItem { Label("Me", systemImage: "person.crop.circle") }
                .tag(AppModel.Tab.me)
        }
        .tint(model.theme.accent)
        .sheet(item: $model.composeTarget) { target in
            MessageComposer(person: target.person, messageText: target.body) { sent in
                model.composeTarget = nil
                if sent {
                    // Log right away; celebrate once the Messages sheet is out of the way.
                    let result = model.markContacted(target.person.id, celebrate: false)
                    model.celebrate(result, after: .milliseconds(700))
                }
            }
            .ignoresSafeArea()
        }
        .fullScreenCover(item: $model.celebration) { result in
            CelebrationView(result: result) { model.celebration = nil }
        }
    }
}
