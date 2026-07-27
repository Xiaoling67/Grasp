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
                Button(vm.isRecording && vm.activeTabId == "live" ? "New Note" : "New Lecture") {
                    vm.handleCommandN()
                }
                .keyboardShortcut("n", modifiers: [.command])
            }
            CommandMenu("Edit") {
                Button("Pause/Resume Recording") { vm.togglePause() }
                    .keyboardShortcut("p", modifiers: [.command, .shift])
                    .disabled(!vm.isRecording)

                Divider()

                Button("Save as Knowledge") { handleShortcutSave(vm: vm, type: "knowledge") }
                    .keyboardShortcut("k", modifiers: [.command, .shift])
                    .disabled(!vm.isRecording)

                Button("Save as Language") { handleShortcutSave(vm: vm, type: "language") }
                    .keyboardShortcut("l", modifiers: [.command, .shift])
                    .disabled(!vm.isRecording || vm.activeLectureMode != "international")

                Button("Search Selection") { handleShortcutSearch(vm: vm) }
                    .keyboardShortcut("e", modifiers: [.command, .shift])
                    .disabled(!vm.isRecording)

                Divider()

                Button("Export…") { vm.showExportModal = true }
                    .keyboardShortcut("x", modifiers: [.command, .shift])
            }
        }
    }

    // MARK: - Keyboard Shortcut Handlers

    @MainActor
    private func handleShortcutSave(vm: AppViewModel, type: String) {
        let text = AppViewModel.lastSelectedText
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            vm.showToast("No text selected.", type: "info")
            return
        }
        if type == "language" && vm.activeLectureMode != "international" {
            vm.showToast("Language saving is only available in International mode.", type: "info")
            return
        }
        vm.handleSaveAction(type: type, text: text)
    }

    @MainActor
    private func handleShortcutSearch(vm: AppViewModel) {
        let text = AppViewModel.lastSelectedText
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            vm.showToast("No text selected.", type: "info")
            return
        }
        vm.triggerSearch(query: text, blockIndex: 0)
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
