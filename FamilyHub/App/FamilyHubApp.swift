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
        TabView {
            TodayView()
                .tabItem { Label("Today", systemImage: "bubble.left.and.bubble.right.fill") }
            PeopleView()
                .tabItem { Label("People", systemImage: "person.2.fill") }
            AboutMeView()
                .tabItem { Label("About Me", systemImage: "person.crop.circle") }
        }
        .sheet(item: $model.composeTarget) { target in
            MessageComposer(person: target.person, messageText: target.body) { sent in
                if sent { model.markContacted(target.person.id) }
                model.composeTarget = nil
            }
            .ignoresSafeArea()
        }
    }
}
