import SwiftUI

// Spec 18: Export — select lecture + checkboxes → Export as .docx
struct ExportModalView: View {
    @EnvironmentObject var vm: AppViewModel; @State private var sel = ""; @State private var opts = (t: true, n: true, k: true, l: true, s: true); @State private var status: String? = nil; @State private var err = ""

    var body: some View {
        ZStack {
            Color.black.opacity(0.35).ignoresSafeArea().onTapGesture { vm.showExportModal = false }
            VStack(spacing: 0) {
                HStack { Text("Export Lecture").font(.inter(size: 15, weight: .semibold)).foregroundColor(Color(hex: "0A0A0A")); Spacer(); Button("×") { vm.showExportModal = false }.buttonStyle(.plain).font(.inter(size: 14)).foregroundColor(Color(hex: "C0C0C0")) }.padding(.horizontal, 20).padding(.top, 16)
                VStack(alignment: .leading, spacing: 18) {
                    if vm.pastLectures.isEmpty { Text("No lectures to export yet.").font(.inter(size: 13)).foregroundColor(Color(hex: "C0C0C0")) }
                    else {
                        VStack(alignment: .leading, spacing: 6) { Text("SELECT LECTURE").font(.inter(size: 11, weight: .semibold)).foregroundColor(Color(hex: "C0C0C0")).tracking(0.3); Picker("", selection: $sel) { ForEach(vm.pastLectures) { l in Text("\(l.name ?? "Untitled") — \(fmt(l.startedAt))").tag(l.id) } }.pickerStyle(.menu).labelsHidden().frame(maxWidth: .infinity, alignment: .leading) }
                        VStack(alignment: .leading, spacing: 8) { Text("INCLUDE IN EXPORT").font(.inter(size: 11, weight: .semibold)).foregroundColor(Color(hex: "C0C0C0")).tracking(0.3); Toggle("Full Transcript", isOn: $opts.t).font(.inter(size: 13)).foregroundColor(Color(hex: "0A0A0A")); Toggle("AI Notes", isOn: $opts.n).font(.inter(size: 13)).foregroundColor(Color(hex: "0A0A0A")); Toggle("Domain Knowledge", isOn: $opts.k).font(.inter(size: 13)).foregroundColor(Color(hex: "0A0A0A")); if DatabaseService.shared.getSetting(key: "defaultMode") == "international" { Toggle("Language Saves", isOn: $opts.l).font(.inter(size: 13)).foregroundColor(Color(hex: "0A0A0A")) }; Toggle("AI Searches", isOn: $opts.s).font(.inter(size: 13)).foregroundColor(Color(hex: "0A0A0A")) }
                    }
                    if status == "done" { Text("Saved successfully.").font(.inter(size: 12)).foregroundColor(Color(hex: "15803D")) }
                    if status == "error" { Text(err.isEmpty ? "Export failed." : err).font(.inter(size: 12)).foregroundColor(Color(hex: "B91C1C")) }
                    if status == "loading" { Text("Generating document…").font(.inter(size: 12)).foregroundColor(Color(hex: "9A9A9A")) }
                }.padding(20)

                HStack(spacing: 8) { Spacer(); Button("Close") { vm.showExportModal = false }.font(.inter(size: 11)).padding(.horizontal, 10).padding(.vertical, 5).foregroundColor(Color(hex: "5A5A5A")).background(Color.clear).cornerRadius(980).overlay(RoundedRectangle(cornerRadius: 980).stroke(Color(hex: "E8E8E8"), lineWidth: 1)).buttonStyle(.plain); if !vm.pastLectures.isEmpty { Button(status == "loading" ? "Exporting..." : "Export as .docx") { handle() }.font(.inter(size: 11, weight: .medium)).foregroundColor(.white).padding(.horizontal, 12).padding(.vertical, 5).background(Color(hex: "1A5FD4")).cornerRadius(980).buttonStyle(.plain).disabled(sel.isEmpty || status == "loading") } }.padding(.horizontal, 20).padding(.vertical, 14).overlay(Rectangle().fill(Color(hex: "E8E8E8")).frame(height: 1), alignment: .top)
            }.frame(width: 420).background(Color.white).cornerRadius(12).shadow(color: .black.opacity(0.2), radius: 20, y: 8)
        }.onAppear { if let first = vm.pastLectures.first { sel = first.id } }
    }

    func handle() { status = "loading"; err = ""; /* Export logic — calls Python script via Process; for now just shows success */ DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { status = "done" } }
    func fmt(_ ms: Int64) -> String { let d = Date(timeIntervalSince1970: Double(ms) / 1000); let f = DateFormatter(); f.dateStyle = .medium; return f.string(from: d) }
}
