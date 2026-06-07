import SwiftUI

// Spec 4.4: 44px, #FFF, border-bottom:1px #E8E8E8, pad:0 12px 0 76px
struct TopBarView: View {
    @EnvironmentObject var vm: AppViewModel
    var body: some View {
        HStack(spacing: 8) {
            Spacer().frame(width: 64)
            // Sidebar toggle — 16x16 SVG icon
            Button(action: { vm.sidebarVisible.toggle() }) { SidebarIcon().frame(width: 28, height: 28) }.buttonStyle(.plain)
            // + New Lecture pill — 12px/500/#5A5A5A, pill radius, 1px #E8E8E8
            Button(action: { vm.showNewLectureModal = true }) {
                Text("+ New Lecture").font(.inter(size: 12, weight: .medium)).foregroundColor(Color(hex: "5A5A5A"))
                    .padding(.horizontal, 10).padding(.vertical, 4).background(Color.white).cornerRadius(980)
                    .overlay(RoundedRectangle(cornerRadius: 980).stroke(Color(hex: "E8E8E8"), lineWidth: 1))
            }.buttonStyle(.plain)
            // Tabs
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 2) { ForEach(vm.tabs) { t in TabPill(tab: t) } }.padding(.vertical, 4)
            }
            Spacer()
            // Recording controls — ⏸/▶ pause, ■ stop
            if vm.isRecording {
                HStack(spacing: 4) {
                    Button(action: { vm.togglePause() }) {
                        Text(vm.isPaused ? "▶" : "⏸").font(.inter(size: 12)).foregroundColor(Color(hex: "5A5A5A")).frame(width: 28, height: 28)
                    }.buttonStyle(.plain).overlay(RoundedRectangle(cornerRadius: 4).stroke(Color(hex: "E8E8E8"), lineWidth: 1))
                    Button(action: { Task { await vm.stopLecture() } }) {
                        Text("■").font(.inter(size: 10)).foregroundColor(Color(hex: "B91C1C")).frame(width: 28, height: 28)
                    }.buttonStyle(.plain).overlay(RoundedRectangle(cornerRadius: 4).stroke(Color(hex: "DC3545").opacity(0.3), lineWidth: 1))
                }.padding(.trailing, 12)
            }
        }
        .frame(height: 38).background(Color.white)
        .overlay(Rectangle().fill(Color(hex: "E8E8E8")).frame(height: 1), alignment: .bottom)
    }
}

struct SidebarIcon: View {
    var body: some View {
        Canvas { ctx, size in
            let r = CGRect(x: 2, y: 2, width: 14, height: 14)
            ctx.stroke(Path(roundedRect: r, cornerRadius: 2.5), with: .color(Color(hex: "9A9A9A")), lineWidth: 1.2)
            let x = size.width * 5.5 / 16; var l = Path(); l.move(to: CGPoint(x: x, y: 2)); l.addLine(to: CGPoint(x: x, y: r.maxY))
            ctx.stroke(l, with: .color(Color(hex: "9A9A9A")), lineWidth: 1.2)
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
                    RoundedRectangle(cornerRadius: 1).fill(Color(hex: "1A5FD4")).frame(width: 2, height: i==1 ? 8 : 4)
                }}.frame(width: 10)
            }
            Text(tab.label).font(.inter(size: 12)).lineLimit(1)
            if !l || !vm.isRecording { Button(action: { vm.closeTab(id: tab.id) }) { Text("×").font(.inter(size: 13)) }.buttonStyle(.plain) }
        }
        .padding(EdgeInsets(top: 3, leading: 8, bottom: 3, trailing: 10))
        .background(a && l ? Color(hex: "E8F0FE") : a ? Color.white : Color.clear).cornerRadius(4)
        .overlay(a && l ? RoundedRectangle(cornerRadius: 4).stroke(Color(hex: "C5D8FC"), lineWidth: 1) : a ? RoundedRectangle(cornerRadius: 4).stroke(Color(hex: "E8E8E8"), lineWidth: 1) : nil)
        .shadow(color: a && !l ? .black.opacity(0.05) : .clear, radius: 3, y: 1)
        .foregroundColor(a && l ? Color(hex: "1A5FD4") : a ? Color(hex: "0A0A0A") : Color(hex: "9A9A9A"))
        .onTapGesture { vm.activeTabId = tab.id }
    }
}
