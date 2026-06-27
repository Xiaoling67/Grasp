import SwiftUI
import AppKit

// Spec 18: Export — select lecture + checkboxes → Export as RTF
struct ExportModalView: View {
    @EnvironmentObject var vm: AppViewModel
    @State private var sel = ""
    @State private var opts = (t: true, n: true, k: true, l: true, s: true)
    @State private var status: String? = nil
    @State private var err = ""

    var body: some View {
        ZStack {
            Color.black.opacity(0.35).ignoresSafeArea().onTapGesture { vm.showExportModal = false }
            VStack(spacing: 0) {
                HStack {
                    Text("Export Lecture").font(.inter(size: 15, weight: .semibold)).foregroundColor(Color.nearBlack)
                    Spacer()
                    Button("×") { vm.showExportModal = false }.buttonStyle(.plain).font(.inter(size: 14)).foregroundColor(Color.mutedGray)
                }.padding(.horizontal, 20).padding(.top, 16)

                VStack(alignment: .leading, spacing: 18) {
                    if vm.pastLectures.isEmpty {
                        Text("No lectures to export yet.").font(.inter(size: 13)).foregroundColor(Color.mutedGray)
                    } else {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("SELECT LECTURE").font(.inter(size: 11, weight: .semibold)).foregroundColor(Color.mutedGray).tracking(0.3)
                            Picker("", selection: $sel) {
                                ForEach(vm.pastLectures) { l in
                                    Text("\(l.name ?? "Untitled") — \(fmt(l.startedAt))").tag(l.id)
                                }
                            }.pickerStyle(.menu).labelsHidden().frame(maxWidth: .infinity, alignment: .leading)
                        }
                        VStack(alignment: .leading, spacing: 8) {
                            Text("INCLUDE IN EXPORT").font(.inter(size: 11, weight: .semibold)).foregroundColor(Color.mutedGray).tracking(0.3)
                            Toggle("Full Transcript", isOn: $opts.t).font(.inter(size: 13)).foregroundColor(Color.nearBlack)
                            Toggle("AI Notes", isOn: $opts.n).font(.inter(size: 13)).foregroundColor(Color.nearBlack)
                            Toggle("Domain Knowledge", isOn: $opts.k).font(.inter(size: 13)).foregroundColor(Color.nearBlack)
                            if DatabaseService.shared.getSetting(key: "defaultMode") == "international" {
                                Toggle("Language Saves", isOn: $opts.l).font(.inter(size: 13)).foregroundColor(Color.nearBlack)
                            }
                            Toggle("AI Searches", isOn: $opts.s).font(.inter(size: 13)).foregroundColor(Color.nearBlack)
                        }
                    }
                    if status == "done" { Text("Saved successfully.").font(.inter(size: 12)).foregroundColor(Color.accentGreen) }
                    if status == "error" { Text(err.isEmpty ? "Export failed." : err).font(.inter(size: 12)).foregroundColor(Color.accentRed) }
                    if status == "loading" { Text("Generating document…").font(.inter(size: 12)).foregroundColor(Color.textTertiary) }
                }.padding(20)

                HStack(spacing: 8) {
                    Spacer()
                    Button("Close") { vm.showExportModal = false }
                        .font(.inter(size: 11)).padding(.horizontal, 10).padding(.vertical, 5)
                        .foregroundColor(Color.mediumGray).background(Color.clear).cornerRadius(980)
                        .overlay(RoundedRectangle(cornerRadius: 980).stroke(Color.pillBorderGray, lineWidth: 1)).buttonStyle(.plain)
                    if !vm.pastLectures.isEmpty {
                        Button(status == "loading" ? "Exporting..." : "Export as .rtf") { handle() }
                            .font(.inter(size: 11, weight: .medium)).foregroundColor(.white)
                            .padding(.horizontal, 12).padding(.vertical, 5)
                            .background(Color.aiNewBorder).cornerRadius(980).buttonStyle(.plain)
                            .disabled(sel.isEmpty || status == "loading")
                    }
                }.padding(.horizontal, 20).padding(.vertical, 14)
                    .overlay(Rectangle().fill(Color.pillBorderGray).frame(height: 1), alignment: .top)
            }.frame(width: 420).background(Color.white).cornerRadius(12).shadow(color: .black.opacity(0.2), radius: 20, y: 8)
        }.onAppear { if let first = vm.pastLectures.first { sel = first.id } }
    }

    func handle() {
        guard !sel.isEmpty else { return }
        status = "loading"; err = ""
        let name = vm.pastLectures.first(where: { $0.id == sel })?.name ?? ""
        DispatchQueue.main.async {
            do {
                let saved = try buildAndSaveRTF(lectureId: sel, name: name)
                status = saved ? "done" : nil   // nil = user cancelled panel
            } catch {
                status = "error"; err = error.localizedDescription
            }
        }
    }

    @discardableResult
    func buildAndSaveRTF(lectureId: String, name: String) throws -> Bool {
        let db = DatabaseService.shared
        let doc = NSMutableAttributedString()

        func h1(_ s: String) { doc.append(NSAttributedString(string: s + "\n", attributes: [.font: NSFont.boldSystemFont(ofSize: 18)])) }
        func h2(_ s: String) { doc.append(NSAttributedString(string: "\n" + s + "\n", attributes: [.font: NSFont.boldSystemFont(ofSize: 14), .foregroundColor: NSColor(calibratedRed: 0.1, green: 0.37, blue: 0.83, alpha: 1)])) }
        func body(_ s: String) { doc.append(NSAttributedString(string: s + "\n", attributes: [.font: NSFont.systemFont(ofSize: 12)])) }
        func muted(_ s: String) { doc.append(NSAttributedString(string: s + "\n", attributes: [.font: NSFont.systemFont(ofSize: 11), .foregroundColor: NSColor.secondaryLabelColor])) }
        func divider() { doc.append(NSAttributedString(string: "\n" + String(repeating: "─", count: 48) + "\n\n", attributes: [.font: NSFont.systemFont(ofSize: 10), .foregroundColor: NSColor.tertiaryLabelColor])) }

        h1(name.isEmpty ? "Untitled Lecture" : name)
        let df = DateFormatter(); df.dateStyle = .long; df.timeStyle = .short
        muted("Exported " + df.string(from: Date()))
        divider()

        if opts.t {
            let blocks = db.getBlocks(lectureId: lectureId)
            if !blocks.isEmpty {
                h2("Transcript")
                for b in blocks {
                    body(b.textEn)
                    if let zh = b.textZh, !zh.isEmpty { muted(zh) }
                }
                divider()
            }
        }

        if opts.n {
            let notes = db.getNoteBlocks(lectureId: lectureId)
            if !notes.isEmpty {
                h2("AI Notes")
                var lastSlide = -1
                for n in notes {
                    if n.slideIndex != lastSlide {
                        if let title = n.slideTitle, !title.isEmpty {
                            doc.append(NSAttributedString(string: "\n" + title + "\n", attributes: [.font: NSFont.boldSystemFont(ofSize: 12)]))
                        }
                        lastSlide = n.slideIndex
                    }
                    let indent = String(repeating: "    ", count: n.level)
                    body(indent + (n.level == 0 ? "▸ " : "• ") + n.content)
                }
                divider()
            }
        }

        for (flag, type, heading) in [(opts.k, "knowledge", "Knowledge Notes"), (opts.l, "language", "Language Notes")] {
            if flag {
                let saves = db.getSaves(lectureId: lectureId).filter { $0.type == type }
                if !saves.isEmpty {
                    h2(heading)
                    for s in saves {
                        body("• " + s.original)
                        if let t = s.translation, !t.isEmpty { muted("  " + t) }
                        if let note = s.note, !note.isEmpty { muted("  Note: " + note) }
                    }
                    divider()
                }
            }
        }

        if opts.s {
            let searches = db.getSearches(lectureId: lectureId)
            if !searches.isEmpty {
                h2("AI Search Records")
                for s in searches {
                    doc.append(NSAttributedString(string: "Q: " + s.query + "\n", attributes: [.font: NSFont.boldSystemFont(ofSize: 12)]))
                    if !s.resultPro.isEmpty { body(s.resultPro) }
                    if !s.resultSimple.isEmpty { muted(s.resultSimple) }
                    doc.append(NSAttributedString(string: "\n"))
                }
            }
        }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.rtf]
        panel.nameFieldStringValue = (name.isEmpty ? "Lecture" : name) + ".rtf"
        panel.message = "Choose where to save"
        guard panel.runModal() == .OK, let url = panel.url else { return false }
        let rtfData = try doc.data(from: NSRange(location: 0, length: doc.length), documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf])
        try rtfData.write(to: url)
        return true
    }

    func fmt(_ ms: Int64) -> String {
        let d = Date(timeIntervalSince1970: Double(ms) / 1000)
        let f = DateFormatter(); f.dateStyle = .medium; return f.string(from: d)
    }
}
