import SwiftUI

// v1.1-r2: Instant selection popup — no debounce, no asyncAfter.
// Uses NSTextView.didChangeSelectionNotification directly on main queue.
// Popup appears within 1 frame (≤16ms) of user completing selection.
struct TranscriptPanelView: View {
    @EnvironmentObject var vm: AppViewModel
    @State private var popup: (String, Int, CGFloat, CGFloat)? = nil
    @State private var panelFrame: CGRect = .zero
    @State private var selectionObserver: Any? = nil

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            if vm.liveBlocks.isEmpty && vm.interimText.isEmpty {
                                Text(vm.isRecording ? "Listening… speak now." : "Start a lecture to begin transcription.")
                                    .font(.inter(size: 14)).foregroundColor(.textTertiary).padding(.top, 60).padding(.horizontal, Spacing.xxl)
                            } else {
                                ForEach(vm.liveBlocks) { b in
                                    BlockView(block: b, isActive: b.id == vm.activeBlockId).id(b.id)
                                }
                                if !vm.interimText.isEmpty && vm.activeBlockId == nil {
                                    Text(vm.interimText).font(.inter(size: 13)).foregroundColor(.textSecondary).padding(.horizontal, 14).padding(.vertical, 10)
                                }
                                Color.clear.frame(height: 40).id("bot")
                            }
                        }.padding(.horizontal, Spacing.xxl).padding(.vertical, Spacing.xl)
                    }
                    .onChange(of: vm.liveBlocks.count) { withAnimation(.easeInOut(duration: 0.2)) { proxy.scrollTo("bot", anchor: .bottom) } }
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
                    // Transparent overlay to dismiss popup on outside tap
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture { popup = nil }
                        .allowsHitTesting(true)

                    SelectionPopupView(query: p.0, blockIndex: p.1, x: p.2, y: p.3, onDismiss: { popup = nil })
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                        .focusable()
                        .onKeyPress(.escape) { popup = nil; return .handled }
                }
            }
            .background(Color.surfacePrimary)
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

                    // Position popup — calculate in same runloop cycle
                    if let lm = tv.layoutManager, let tc = tv.textContainer {
                        let glyphRange = lm.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
                        let rect = lm.boundingRect(forGlyphRange: glyphRange, in: tc)
                        let windowRect = tv.convert(rect, to: nil)
                        let popupX = windowRect.midX - panelFrame.minX
                        let popupY = (tv.window?.contentView?.frame.height ?? 600) - windowRect.minY - panelFrame.minY

                        // Position above selection by default; below if clipped
                        let aboveY = popupY + 4  // 4px gap above
                        let belowY = popupY - rect.height - 4  // below selection
                        let useAbove = aboveY > 80  // enough room above?
                        popup = (selected, 0, popupX, useAbove ? aboveY : belowY)
                    }
                }
            }
            .onDisappear {
                if let obs = selectionObserver {
                    NotificationCenter.default.removeObserver(obs)
                    selectionObserver = nil
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

// Spec 4.8: block — 13px EN / 12px ZH / active dot / timestamp / highlight
struct BlockView: View {
    @EnvironmentObject var vm: AppViewModel; let block: LiveBlock; let isActive: Bool

    private var bgColor: Color {
        if vm.highlightedBlockIds.contains(block.id) {
            return .selectionBg
        }
        if isActive {
            return Color.surfaceSecondary
        }
        return Color.clear
    }

    private var timestampStr: String? {
        guard let createdAt = block.createdAt, let lectureStart = vm.activeLectureId else { return nil }
        let firstBlockTs = vm.liveBlocks.first(where: { $0.createdAt != nil })?.createdAt ?? createdAt
        let offsetMs = createdAt - firstBlockTs
        let totalSeconds = max(0, Int(offsetMs / 1000))
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            if isActive {
                Text(block.textEn).font(.inter(size: 13)).foregroundColor(.textPrimary).textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
            } else {
                Text(block.textEn).font(.inter(size: 13)).foregroundColor(.textPrimary).textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
            }
            if let zh = block.textZh, !zh.isEmpty { Text(zh).font(.inter(size: 12)).foregroundColor(.textSecondary).textSelection(.enabled).fixedSize(horizontal: false, vertical: true) }
            if block.isSealed, let ts = timestampStr {
                Text(ts).font(.inter(size: 9, weight: .medium)).foregroundColor(.textTertiary).padding(.top, 2)
            }
            if isActive { HStack(spacing: 5) { Circle().fill(Color.accentBlue).frame(width: 6, height: 6); Text("Transcribing...").font(.inter(size: 10)).foregroundColor(.textTertiary) }.padding(.top, 2) }
        }
        .padding(.horizontal, Spacing.sm).padding(.vertical, 10)
        .background(bgColor)
        .cornerRadius(CornerRadius.card)
        .contextMenu {
            Button("Save as Knowledge (K)") { vm.handleSaveAction(type: "knowledge", text: block.textEn) }
            if vm.activeLectureMode == "international" { Button("Save as Language (L)") { vm.handleSaveAction(type: "language", text: block.textEn) } }
            Divider()
            Button("AI Search") { vm.triggerSearch(query: block.textEn, blockIndex: block.blockIndex) }
            Button("Copy to Notes") { vm.handleCopyToNotes(text: block.textEn) }
        }
    }
}
