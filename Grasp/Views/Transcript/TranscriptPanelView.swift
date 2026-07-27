import SwiftUI

// v1.1-r2: Instant selection popup — no debounce, no asyncAfter.
// Uses NSTextView.didChangeSelectionNotification directly on main queue.
// Popup appears within 1 frame (≤16ms) of user completing selection.
struct TranscriptPanelView: View {
    @EnvironmentObject var vm: AppViewModel
    @State private var popup: SelectionPopupState? = nil
    @State private var panelFrame: CGRect = .zero
    @State private var selectionObserver: Any? = nil
    @State private var scrollObservers = [Any]()
    @State private var keyMonitor: Any? = nil

    var body: some View {
        VStack(spacing: 0) {
            PanelHeaderView(title: "TRANSCRIPT", status: transcriptStatus) {
                EmptyView()
            } settings: {
                PanelInfoSettingsPopover(
                    title: "Transcript Settings",
                    bodyText: "Transcript blocks are sealed into AI Notes after enough useful speech is captured. Select transcript text to save, search, or copy it into notes."
                )
            }

            GeometryReader { geo in
                ZStack(alignment: .bottom) {
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 0) {
                                if vm.liveBlocks.isEmpty && vm.interimText.isEmpty {
                                    Text(vm.isRecording ? "Listening… speak now." : "Start a lecture to begin transcription.")
                                        .font(.inter(size: vm.transcriptEnglishFontSize + 1)).foregroundColor(.textTertiary).padding(.top, 60).padding(.horizontal, Spacing.xxl)
                                } else {
                                    ForEach(vm.liveBlocks) { b in
                                        BlockView(block: b, isActive: b.id == vm.activeBlockId).id(b.id)
                                    }
                                    if !vm.interimText.isEmpty && vm.activeBlockId == nil {
                                        Text(vm.interimText).font(.inter(size: vm.transcriptEnglishFontSize)).foregroundColor(.textSecondary).padding(.horizontal, 14).padding(.vertical, 10)
                                    }
                                    Color.clear.frame(height: 40).id("bot")
                                }
                            }.padding(.horizontal, Spacing.xxl).padding(.vertical, Spacing.xl)
                        }
                        .onHover { hovering in
                            guard vm.hoverFreezeEnabled else { return }
                            vm.isScrollFrozen = hovering
                        }
                        .onChange(of: vm.liveBlocks.count) {
                            guard !vm.isScrollFrozen else { return }
                            withAnimation(.easeInOut(duration: 0.2)) { proxy.scrollTo("bot", anchor: .bottom) }
                        }
                    }
                    if vm.isScrollFrozen, let last = vm.liveBlocks.last {
                        HStack(spacing: Spacing.sm) {
                            Text(String(last.textEn.prefix(80))).font(.inter(size: 11)).italic().foregroundColor(.textTertiary).lineLimit(1)
                            Spacer()
                            Button("Resume") { vm.isScrollFrozen = false }.font(.inter(size: 11, weight: .medium)).foregroundColor(.accentBlue).padding(.horizontal, Spacing.xs).padding(.vertical, Spacing.xxs).background(Color.selectionBg).cornerRadius(CornerRadius.pill).overlay(RoundedRectangle(cornerRadius: CornerRadius.pill).stroke(Color.lightBlueBorder, lineWidth: 1)).buttonStyle(.plain)
                        }.padding(.horizontal, Spacing.md).padding(.vertical, Spacing.xxs).background(.regularMaterial)
                        .overlay(Rectangle().fill(Color.divider).frame(height: 1), alignment: .top)
                    }
                    if let p = popup {
                        Color.clear
                            .contentShape(Rectangle())
                            .onTapGesture { popup = nil }
                            .allowsHitTesting(true)

                        SelectionPopupView(query: p.text, blockIndex: p.blockIndex, x: p.x, y: p.y, panelSize: geo.size, onDismiss: { popup = nil })
                            .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    }
                }
                .background(Color.warmCream)
                .onAppear {
                    panelFrame = geo.frame(in: .global)
                    // v1.1-r2: INSTANT popup — no debounce, no asyncAfter.
                    // Observe NSTextView.didChangeSelectionNotification directly on main queue.
                    // Popup must appear within 1 frame (≤16ms).
                    selectionObserver = NotificationCenter.default.addObserver(
                        forName: NSTextView.didChangeSelectionNotification,
                        object: nil,
                        queue: .main
                    ) { [self] notification in
                        guard let tv = notification.object as? NSTextView,
                              let window = tv.window,
                              window == NSApp.keyWindow,
                              !tv.isEditable, tv.isSelectable else { return }

                        let range = tv.selectedRange()
                        // Minimum selection: 2 characters
                        guard range.length >= 2 else { popup = nil; return }

                        let selected = (tv.string as NSString)
                            .substring(with: range)
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !selected.isEmpty else { popup = nil; return }

                        // Ignore punctuation-only selections
                        let letters = selected.filter { $0.isLetter || $0.isNumber }
                        guard !letters.isEmpty else { popup = nil; return }

                        AppViewModel.lastSelectedText = selected
                        let blockIndex = vm.liveBlocks.first(where: {
                            $0.textEn.contains(selected) || ($0.textZh?.contains(selected) == true)
                        })?.blockIndex ?? 0

                        // Position popup — calculate in same runloop cycle
                        if let lm = tv.layoutManager, let tc = tv.textContainer {
                            let glyphRange = lm.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
                            var rect = lm.boundingRect(forGlyphRange: glyphRange, in: tc)
                            rect.origin.x += tv.textContainerOrigin.x
                            rect.origin.y += tv.textContainerOrigin.y
                            let windowRect = tv.convert(rect, to: nil)
                            let popupX = windowRect.midX - panelFrame.minX
                            let selectionTop = panelFrame.maxY - windowRect.maxY
                            let selectionBottom = panelFrame.maxY - windowRect.minY
                            let aboveY = selectionTop - 22
                            let belowY = selectionBottom + 22
                            let popupY = aboveY >= 18 ? aboveY : belowY
                            popup = SelectionPopupState(text: selected, blockIndex: blockIndex, x: popupX, y: popupY)
                        }
                    }

                    let center = NotificationCenter.default
                    scrollObservers = [
                        center.addObserver(forName: NSScrollView.willStartLiveScrollNotification, object: nil, queue: .main) { _ in
                            popup = nil
                        },
                        center.addObserver(forName: NSScrollView.didLiveScrollNotification, object: nil, queue: .main) { _ in
                            popup = nil
                        }
                    ]
                    keyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { event in
                        guard popup != nil else { return event }
                        popup = nil
                        if event.keyCode == 53 { return nil }
                        return event
                    }
                }
                .onDisappear {
                    if let obs = selectionObserver {
                        NotificationCenter.default.removeObserver(obs)
                        selectionObserver = nil
                    }
                    scrollObservers.forEach(NotificationCenter.default.removeObserver)
                    scrollObservers.removeAll()
                    if let monitor = keyMonitor {
                        NSEvent.removeMonitor(monitor)
                        keyMonitor = nil
                    }
                }
                .onChange(of: geo.size) { _ in
                    panelFrame = geo.frame(in: .global)
                    // Dismiss popup on layout change
                    popup = nil
                }
                .animation(.easeInOut(duration: 0.2), value: popup == nil)
            }
        }
    }

    private var transcriptStatus: String? {
        if vm.isPaused { return "Paused" }
        if vm.isRecording {
            switch vm.deepgramStatus {
            case "connected": return "Live"
            case "connecting": return "Connecting"
            case "reconnecting": return "Reconnecting"
            case "disconnected": return "Disconnected"
            default: return "Listening"
            }
        }
        return nil
    }
}

private struct SelectionPopupState: Equatable {
    let text: String
    let blockIndex: Int
    let x: CGFloat
    let y: CGFloat
}
