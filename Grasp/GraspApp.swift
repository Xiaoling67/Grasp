import SwiftUI

@main struct GraspApp: App {
    @StateObject private var vm = AppViewModel()

    init() { Inter.registerAll() }

    var body: some Scene {
        WindowGroup {
            RootView().environmentObject(vm).frame(minWidth: 960, minHeight: 640)
        }
        .defaultSize(width: 1280, height: 800).windowResizability(.contentMinSize)
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandMenu("Lecture") {
                Button("New Lecture") { vm.showNewLectureModal = true }.keyboardShortcut("n", modifiers: [.command])
            }
        }
    }
}

struct RootView: View {
    @EnvironmentObject var vm: AppViewModel
    var body: some View {
        ZStack {
            VStack(spacing:0) {
                TopBarView()
                HStack(spacing:0) {
                    if vm.sidebarVisible { SidebarView() }
                    MainContent().frame(maxWidth:.infinity, maxHeight:.infinity)
                }
            }
            if vm.showNewLectureModal { NewLectureModalView() }
            if vm.showExportModal { ExportModalView() }
            if vm.onboardingChecked && vm.showOnboarding { OnboardingModalView() }
            if let m = vm.toastMessage { ToastView(message:m, type:vm.toastType) }
        }
    }
}

struct MainContent: View {
    @EnvironmentObject var vm: AppViewModel
    var body: some View {
        if let id = vm.activeTabId, let tab = vm.tabs.first(where:{$0.id==id}) {
            switch tab.type {
            case .live: LiveTabView()
            case .past: PastLectureView(lectureId:tab.lectureId ?? "", lectureMeta: vm.pastLectures.first{$0.id==tab.lectureId})
            }
        } else {
            switch vm.page {
            case .home: HomeView(); case .settings: SettingsView()
            case .saved: SavedItemsView(); case .searched: SearchHistoryView()
            }
        }
    }
}
