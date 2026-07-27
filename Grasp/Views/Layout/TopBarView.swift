import SwiftUI

// Spec 4.4: compact top bar using semantic surfaces and soft pastel dividers.
struct TopBarView: View {
    @EnvironmentObject var vm: AppViewModel
    var body: some View {
        HStack(spacing: 8) {
            Spacer().frame(width: 64)
            // Sidebar toggle — 16x16 SVG icon
            Button(action: { vm.sidebarVisible.toggle() }) { SidebarIcon().frame(width: 18, height: 18) }.buttonStyle(.plain)
            // + New Lecture pill
            Button(action: { vm.showNewLectureModal = true }) {
                Text("+ New Lecture").font(.inter(size: 11)).foregroundColor(Color.mediumGray)
                    .padding(.horizontal, 10).padding(.vertical, 2).background(Color.warmCream).cornerRadius(980)
                    .overlay(RoundedRectangle(cornerRadius: 980).stroke(Color.pillBorderGray, lineWidth: 1))
            }.buttonStyle(.plain)
            // Tabs
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 2) { ForEach(vm.tabs) { t in TabPill(tab: t) } }.padding(.vertical, 1)
            }
            Spacer()
            // Recording controls — ⏸/▶ pause, ■ stop
            if vm.isRecording {
                HStack(spacing: 4) {
                    RecordingControlButton(symbol: vm.isPaused ? "▶" : "⏸", fontSize: 10, color: .mediumGray, borderColor: .pillBorderGray) {
                        vm.togglePause()
                    }
                    RecordingControlButton(symbol: "■", fontSize: 9, color: .accentRed, borderColor: .stopBorderRed.opacity(0.3)) {
                        Task { await vm.stopLecture() }
                    }
                }.padding(.trailing, 8)
            }
        }
        .frame(height: 22).background(Color.appBackground)
        .overlay(Rectangle().fill(Color.pillBorderGray).frame(height: 1), alignment: .bottom)
    }
}

// Pause/stop hit targets were too small (18x16) to click reliably, which read as
// "unresponsive" — this widens the tap area and adds hover/press feedback so a click
// is visibly acknowledged even before the state actually changes.
struct RecordingControlButton: View {
    let symbol: String; let fontSize: CGFloat; let color: Color; let borderColor: Color
    let action: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Text(symbol).font(.inter(size: fontSize)).foregroundColor(color)
                .frame(width: 26, height: 22)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(isHovering ? Color.pillBorderGray.opacity(0.35) : Color.clear)
        .cornerRadius(3)
        .overlay(RoundedRectangle(cornerRadius: 3).stroke(borderColor, lineWidth: 1))
        .onHover { isHovering = $0 }
    }
}

struct SidebarIcon: View {
    var body: some View {
        Canvas { ctx, size in
            let r = CGRect(x: 2, y: 2, width: 14, height: 14)
            ctx.stroke(Path(roundedRect: r, cornerRadius: 2.5), with: .color(Color.textTertiary), lineWidth: 1.2)
            let x = size.width * 5.5 / 16; var l = Path(); l.move(to: CGPoint(x: x, y: 2)); l.addLine(to: CGPoint(x: x, y: r.maxY))
            ctx.stroke(l, with: .color(Color.textTertiary), lineWidth: 1.2)
        }.frame(width: 16, height: 16)
    }
}

// TabBar.jsx: .tab { 12px, pad:3px 10px 3px 8px, radius:4px }
struct TabPill: View {
    @EnvironmentObject var vm: AppViewModel; let tab: TabItem
    var body: some View {
        let a = vm.activeTabId == tab.id, l = tab.type == .live
        HStack(spacing: 5) {
            if l && vm.isRecording && !vm.isPaused {
                HStack(spacing: 1.5) { ForEach(0..<3, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 1).fill(Color.aiNewBorder).frame(width: 2, height: i==1 ? 8 : 4)
                }}.frame(width: 10)
            }
            Text(tab.label).font(.inter(size: 12, weight: .light)).lineLimit(1)
            if !l || !vm.isRecording { Button(action: { vm.closeTab(id: tab.id) }) { Text("×").font(.inter(size: 11)) }.buttonStyle(.plain) }
        }
        .padding(EdgeInsets(top: 1, leading: 6, bottom: 1, trailing: 8))
        .background(a && l ? Color.lightBlueBg : a ? Color.warmCream : Color.clear).cornerRadius(8)
        .overlay(a && l ? RoundedRectangle(cornerRadius: 8).stroke(Color.lightBlueBorder, lineWidth: 1) : a ? RoundedRectangle(cornerRadius: 8).stroke(Color.pillBorderGray, lineWidth: 1) : nil)
        .shadow(color: a && !l ? .black.opacity(0.05) : .clear, radius: 3, y: 1)
        .foregroundColor(a && l ? Color.aiNewBorder : a ? Color.nearBlack : Color.textTertiary)
        .onTapGesture { vm.activeTabId = tab.id }
    }
}
