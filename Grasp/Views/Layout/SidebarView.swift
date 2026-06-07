import SwiftUI

// Spec 4.5: 200px, bg:#F8F8F8, border-right:1px #E8E8E8
struct SidebarView: View {
    @EnvironmentObject var vm: AppViewModel
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                Text("Grasp").font(.inter(size: 15, weight: .bold)).tracking(-0.4)
                    .foregroundColor(Color(hex: "0A0A0A")).frame(maxWidth: .infinity, alignment: .leading)
                    .padding(EdgeInsets(top: 16, leading: 16, bottom: 12, trailing: 16))
                VStack(spacing: 1) {
                    NavItem(label: "Home", page: .home); NavItem(label: "Saved", page: .saved); NavItem(label: "Search History", page: .searched)
                    Button(action: { vm.pastExpanded.toggle() }) {
                        HStack { Text("Past Lectures").font(.inter(size: 13, weight: .medium)).foregroundColor(Color(hex: "0A0A0A")); Spacer()
                            Text(vm.pastExpanded ? "▾" : "▸").font(.inter(size: 11)).foregroundColor(Color(hex: "C0C0C0")) }
                        .padding(EdgeInsets(top: 6, leading: 10, bottom: 6, trailing: 10))
                    }.buttonStyle(.plain)
                    if vm.pastExpanded {
                        VStack(spacing: 1) {
                            if vm.pastLectures.isEmpty { Text("No lectures yet").font(.inter(size: 11)).foregroundColor(Color(hex: "C0C0C0")).padding(EdgeInsets(top: 4, leading: 10, bottom: 4, trailing: 10)).frame(maxWidth: .infinity, alignment: .leading) }
                            else { ForEach(vm.pastLectures.prefix(8)) { l in
                                Button(action: { vm.openPastLecture(id: l.id, name: l.name) }) {
                                    Text(l.name ?? "Untitled Lecture").font(.inter(size: 12)).lineLimit(1).foregroundColor(Color(hex: "5A5A5A")).padding(EdgeInsets(top: 4, leading: 10, bottom: 4, trailing: 10)).frame(maxWidth: .infinity, alignment: .leading).cornerRadius(4)
                                }.buttonStyle(.plain)
                            }}
                        }.padding(.leading, 10)
                    }
                }.padding(EdgeInsets(top: 0, leading: 8, bottom: 16, trailing: 8))
                Rectangle().fill(Color(hex: "E8E8E8")).frame(height: 1).padding(EdgeInsets(top: 8, leading: 4, bottom: 8, trailing: 4))
                VStack(spacing: 1) {
                    Button(action: { vm.showExportModal = true }) { Text("Export").font(.inter(size: 13)).foregroundColor(Color(hex: "5A5A5A")).padding(EdgeInsets(top: 6, leading: 10, bottom: 6, trailing: 10)).frame(maxWidth: .infinity, alignment: .leading) }.buttonStyle(.plain)
                    NavItem(label: "Settings", page: .settings)
                }.padding(.horizontal, 8)
            }
        }.frame(width: 200).background(Color(hex: "F8F8F8"))
        .overlay(Rectangle().fill(Color(hex: "E8E8E8")).frame(width: 1), alignment: .trailing)
    }
}

struct NavItem: View {
    let label: String; let page: AppPage; @EnvironmentObject var vm: AppViewModel
    var a: Bool { vm.page == page && vm.activeTabId == nil }
    var body: some View {
        Button(action: { vm.activeTabId = nil; vm.page = page }) {
            Text(label).font(.inter(size: 13)).fontWeight(a ? .medium : .regular)
                .foregroundColor(a ? Color(hex: "1A5FD4") : Color(hex: "5A5A5A"))
                .padding(EdgeInsets(top: 6, leading: 10, bottom: 6, trailing: 10)).frame(maxWidth: .infinity, alignment: .leading)
                .background(a ? Color(hex: "1A5FD4").opacity(0.08) : Color.clear).cornerRadius(4)
        }.buttonStyle(.plain)
    }
}
