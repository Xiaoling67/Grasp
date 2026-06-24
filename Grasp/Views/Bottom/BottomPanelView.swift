import SwiftUI

// Spec 4.6: Bottom panel — 2 tabs (Explain, Notes), Cold Call as banner
struct BottomPanelView: View {
    @EnvironmentObject var vm: AppViewModel
    @State private var noteFilter: NoteFilter = .all

    enum NoteFilter: String, CaseIterable { case all = "All"; case saved = "Saved"; case searched = "Searched" }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 2) {
                tabBtn("Explain", "explain", badge: vm.autoExplainNew || vm.coldCallPhase != nil)
                tabBtn("Notes", "notes", count: vm.sessionSaves.count + vm.sessionSearches.count)
                Spacer()
            }.padding(.horizontal, 16).frame(height: 32).overlay(Rectangle().fill(Color(hex: "E8E8E8")).frame(height: 1), alignment: .bottom)
            bodyContent
        }.overlay(Rectangle().fill(Color(hex: "E8E8E8")).frame(height: 1), alignment: .top)
    }

    func tabBtn(_ label: String, _ tag: String, count: Int = 0, badge: Bool = false) -> some View {
        Button(action: {
            vm.bottomTab = tag
            if tag == "explain" { vm.autoExplainNew = false }
        }) {
            HStack(spacing: 5) {
                Text(label).font(.inter(size: 11, weight: vm.bottomTab == tag ? .medium : .regular))
                    .foregroundColor(vm.bottomTab == tag ? Color(hex: "0A0A0A") : Color(hex: "9A9A9A"))
                if count > 0 {
                    Text("\(count)").font(.inter(size: 10)).foregroundColor(Color(hex: "5A5A5A"))
                        .padding(.horizontal, 5).background(Color(hex: "E8E8E8")).cornerRadius(10)
                }
                if badge {
                    Circle().fill(Color(hex: "7C3AED")).frame(width: 5, height: 5)
                }
            }.padding(.horizontal, 10).padding(.vertical, 4)
                .background(vm.bottomTab == tag ? Color(hex: "F8F8F8") : Color.clear).cornerRadius(4)
        }.buttonStyle(.plain)
    }

    @ViewBuilder var bodyContent: some View {
        switch vm.bottomTab {
        case "explain":
            VStack(spacing: 0) {
                if let phase = vm.coldCallPhase {
                    ColdCallBanner(phase: phase)
                        .padding(.horizontal, 12).padding(.top, 8)
                }
                if vm.autoExplainResult != nil || vm.autoExplainStreaming {
                    AutoExplainCardView()
                } else if vm.coldCallPhase == nil {
                    Text("Auto-explain activates when the professor uses a concept you may not know.")
                        .font(.inter(size: 12)).foregroundColor(Color(hex: "C0C0C0"))
                        .multilineTextAlignment(.center).padding(16)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    Spacer(minLength: 0)
                }
            }
        case "notes":
            notesView
        default:
            EmptyView()
        }
    }

    @ViewBuilder var notesView: some View {
        VStack(spacing: 0) {
            // Filter bar: All / Saved / Searched
            HStack(spacing: 4) {
                ForEach(NoteFilter.allCases, id: \.rawValue) { f in
                    Button(action: { noteFilter = f }) {
                        Text(f.rawValue).font(.inter(size: 10, weight: noteFilter == f ? .medium : .regular))
                            .foregroundColor(noteFilter == f ? Color(hex: "0A0A0A") : Color(hex: "9A9A9A"))
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(noteFilter == f ? Color(hex: "F0F0F0") : Color.clear).cornerRadius(4)
                    }.buttonStyle(.plain)
                }
                Spacer()
            }.padding(.horizontal, 12).padding(.vertical, 6)

            // Merged list of saves + searches
            ScrollView {
                VStack(spacing: 0) {
                    let saves = noteFilter != .searched ? vm.sessionSaves : []
                    let searches = noteFilter != .saved ? vm.sessionSearches : []
                    let isEmpty = saves.isEmpty && searches.isEmpty
                    if isEmpty {
                        Text("No items yet.").font(.inter(size: 12)).foregroundColor(Color(hex: "C0C0C0")).padding(8)
                    }
                    ForEach(Array(saves.enumerated()), id: \.offset) { _, s in
                        Button(action: {
                            vm.activeCard = .save(SaveDraft(type: s.type, original: s.original, translation: s.translation, lectureId: s.lectureId))
                            vm.bottomTab = "explain"
                        }) {
                            HStack(spacing: 8) {
                                Text(s.type == "knowledge" ? "K" : "L").font(.inter(size: 9, weight: .bold))
                                    .padding(.horizontal, 5).padding(.vertical, 2)
                                    .foregroundColor(s.type == "knowledge" ? Color(hex: "1A5FD4") : Color(hex: "15803D"))
                                    .background(s.type == "knowledge" ? Color(hex: "E8F0FE") : Color(hex: "F0FDF4")).cornerRadius(4)
                                Text(s.original).font(.inter(size: 12)).foregroundColor(Color(hex: "5A5A5A")).lineLimit(1)
                                Spacer()
                            }.padding(.vertical, 6).padding(.horizontal, 8)
                        }.buttonStyle(.plain)
                    }
                    ForEach(searches) { s in
                        Button(action: {
                            vm.activeCard = .search(s)
                            vm.bottomTab = "explain"
                        }) {
                            Text(s.query.isEmpty ? String(s.professional.prefix(60)) : s.query)
                                .font(.inter(size: 12)).foregroundColor(Color(hex: "5A5A5A")).lineLimit(1)
                                .padding(.vertical, 6).padding(.horizontal, 8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }.buttonStyle(.plain)
                    }
                }
            }
        }
    }
}
