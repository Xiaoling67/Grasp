import SwiftUI

// Spec 4.8 & 10: Transcript panel with blocks + PreviewStrip
struct TranscriptPanelView: View {
    @EnvironmentObject var vm: AppViewModel
    @State private var popup: (String, Int, CGFloat, CGFloat)? = nil
    @State private var mouseUpMonitor: Any? = nil
    @State private var panelFrame: CGRect = .zero

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            if vm.liveBlocks.isEmpty && vm.interimText.isEmpty {
                                Text(vm.isRecording ? "Listening… speak now." : "Start a lecture to begin transcription.")
                                    .font(.inter(size: 14)).foregroundColor(Color(hex: "C0C0C0")).padding(.top, 60).padding(.horizontal, 48)
                            } else {
                                ForEach(vm.liveBlocks) { b in
                                    BlockView(block: b, isActive: b.id == vm.activeBlockId).id(b.id)
                                }
                                if !vm.interimText.isEmpty && vm.activeBlockId == nil {
                                    Text(vm.interimText).font(.inter(size: 13)).foregroundColor(Color(hex: "5A5A5A")).padding(.horizontal, 14).padding(.vertical, 10)
                                }
                                Color.clear.frame(height: 40).id("bot")
                            }
                        }.padding(.horizontal, 48).padding(.vertical, 32)
                    }
                    .onChange(of: vm.liveBlocks.count) { withAnimation { proxy.scrollTo("bot", anchor: .bottom) } }
                }
                if vm.isScrollFrozen, let last = vm.liveBlocks.last {
                    HStack(spacing: 12) {
                        Text(String(last.textEn.prefix(80))).font(.inter(size: 11)).italic().foregroundColor(Color(hex: "9A9A9A")).lineLimit(1)
                        Spacer()
                        Button("Resume") { vm.isScrollFrozen = false }.font(.inter(size: 11, weight: .medium)).foregroundColor(Color(hex: "1A5FD4")).padding(.horizontal, 8).padding(.vertical, 2).background(Color(hex: "E8F0FE")).cornerRadius(980).overlay(RoundedRectangle(cornerRadius: 980).stroke(Color(hex: "C5D8FC"), lineWidth: 1)).buttonStyle(.plain)
                    }.padding(.horizontal, 20).padding(.vertical, 6).background(.regularMaterial)
                    .overlay(Rectangle().fill(Color(hex: "D0D0D0")).frame(height: 1), alignment: .top)
                }
                if let p = popup {
                    SelectionPopupView(query: p.0, blockIndex: p.1, x: p.2, y: p.3, onDismiss: { popup = nil })
                }
            }.background(Color.white)
            .onAppear {
                panelFrame = geo.frame(in: .global)
                mouseUpMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseUp) { event in
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                        guard let window = NSApp.keyWindow,
                              let tv = window.firstResponder as? NSTextView else { return }
                        let range = tv.selectedRange()
                        guard range.length > 2 else { popup = nil; return }
                        let selected = (tv.string as NSString)
                            .substring(with: range)
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !selected.isEmpty else { popup = nil; return }
                        AppViewModel.lastSelectedText = selected
                        let winH = window.contentView?.frame.height ?? window.frame.height
                        let localX = event.locationInWindow.x - panelFrame.minX
                        let localY = winH - event.locationInWindow.y - panelFrame.minY
                        popup = (selected, 0, localX, localY)
                    }
                    return event
                }
            }
            .onDisappear {
                if let m = mouseUpMonitor { NSEvent.removeMonitor(m); mouseUpMonitor = nil }
            }
            .onChange(of: geo.size) { _ in panelFrame = geo.frame(in: .global) }
        }
    }
}

// Spec 4.8: block — 13px EN / 12px ZH / active dot
struct BlockView: View {
    @EnvironmentObject var vm: AppViewModel; let block: LiveBlock; let isActive: Bool
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            if isActive {
                Text(block.textEn).font(.inter(size: 13)).foregroundColor(Color(hex: "0A0A0A")).textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
            } else {
                Text(block.textEn).font(.inter(size: 13)).foregroundColor(Color(hex: "0A0A0A")).textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
            }
            if let zh = block.textZh, !zh.isEmpty { Text(zh).font(.inter(size: 12)).foregroundColor(Color(hex: "5A5A5A")).textSelection(.enabled).fixedSize(horizontal: false, vertical: true) }
            if isActive { HStack(spacing: 5) { Circle().fill(Color(hex: "1A5FD4")).frame(width: 6, height: 6); Text("Transcribing...").font(.inter(size: 10)).foregroundColor(Color(hex: "9A9A9A")) }.padding(.top, 2) }
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .contextMenu {
            Button("Save as Knowledge (K)") { vm.handleSaveAction(type: "knowledge", text: block.textEn) }
            if vm.activeLectureMode == "international" { Button("Save as Language (L)") { vm.handleSaveAction(type: "language", text: block.textEn) } }
            Divider()
            Button("AI Search") { vm.triggerSearch(query: block.textEn, blockIndex: block.blockIndex) }
            Button("Copy to Notes") { vm.handleCopyToNotes(text: block.textEn) }
        }
    }
}
