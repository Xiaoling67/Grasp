import SwiftUI

// Spec 4.5: 200px sidebar using the soft app background and semantic divider.
struct SidebarView: View {
    @EnvironmentObject var vm: AppViewModel
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                Text("Grasp").font(.inter(size: 16, weight: .bold))
                    .foregroundColor(Color.nearBlack).frame(maxWidth: .infinity, alignment: .leading)
                    .padding(EdgeInsets(top: 16, leading: 16, bottom: 12, trailing: 16))
                VStack(spacing: 1) {
                    NavItem(label: "Home", page: .home); NavItem(label: "Saved", page: .saved); NavItem(label: "Search History", page: .searched)
                    SidebarRow(action: { vm.pastExpanded.toggle() }, selected: vm.activeTabId?.hasPrefix("past-") == true) {
                        HStack { Text("Past Lectures").font(.inter(size: 13, weight: .medium)); Spacer()
                            Text(vm.pastExpanded ? "▾" : "▸").font(.inter(size: 11)).foregroundColor(Color.mutedGray) }
                    }
                    if vm.pastExpanded {
                        VStack(spacing: 1) {
                            if vm.pastLectures.isEmpty { Text("No lectures yet").font(.inter(size: 11)).foregroundColor(Color.mutedGray).padding(EdgeInsets(top: 4, leading: 10, bottom: 4, trailing: 10)).frame(maxWidth: .infinity, alignment: .leading) }
                            else { ForEach(vm.pastLectures.prefix(8)) { l in
                                SidebarRow(action: { vm.openPastLecture(id: l.id, name: l.name) }, selected: vm.activeTabId == "past-\(l.id)", compact: true) {
                                    Text(l.name ?? "Untitled Lecture").font(.inter(size: 12)).lineLimit(1)
                                }
                            }}
                        }.padding(.leading, 10)
                    }
                }.padding(EdgeInsets(top: 0, leading: 8, bottom: 16, trailing: 8))
                Rectangle().fill(Color.pillBorderGray).frame(height: 1).padding(EdgeInsets(top: 8, leading: 4, bottom: 8, trailing: 4))
                VStack(spacing: 1) {
                    SidebarRow(action: { vm.showExportModal = true }) { Text("Export").font(.inter(size: 13)) }
                    NavItem(label: "Settings", page: .settings)
                }.padding(.horizontal, 8)
            }
        }.frame(width: 200).background(Color.appBackground)
        .overlay(Rectangle().fill(Color.pillBorderGray).frame(width: 1), alignment: .trailing)
    }
}

struct NavItem: View {
    let label: String; let page: AppPage; @EnvironmentObject var vm: AppViewModel
    var a: Bool { vm.page == page && vm.activeTabId == nil }
    var body: some View {
        SidebarRow(action: { vm.activeTabId = nil; vm.page = page }, selected: a) {
            Text(label).font(.inter(size: 13)).fontWeight(a ? .medium : .regular)
        }
    }
}

struct SidebarRow<Content: View>: View {
    let action: () -> Void
    var selected = false
    var compact = false
    @ViewBuilder var content: Content
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(selected ? Color.aiNewBorder : Color.clear)
                    .frame(width: 3)
                    .padding(.vertical, compact ? 5 : 6)
                content
                    .foregroundColor(selected ? Color.aiNewBorder : Color.mediumGray)
                    .padding(EdgeInsets(top: compact ? 4 : 6, leading: 8, bottom: compact ? 4 : 6, trailing: 10))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(selected ? Color.pastelBlue : hovering ? Color.hoverBg : Color.clear)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
    }
}
