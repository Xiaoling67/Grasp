import SwiftUI

// Spec: Save card with Cancel/Save buttons
struct SaveCardView: View {
    @EnvironmentObject var vm: AppViewModel; @State private var note = ""; @State private var saving = false; @State private var saved = false; @State private var error = ""
    private var draft: SaveDraft? { if case .save(let d) = vm.activeCard { return d }; return nil }
    private var isLang: Bool { draft?.type == "language" }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack { Text(isLang ? "LANGUAGE SAVE" : "KNOWLEDGE SAVE").font(.inter(size: 11, weight: .semibold)).foregroundColor(Color.mediumGray); Spacer(); Button("✕") { vm.activeCard = nil }.buttonStyle(.plain).font(.inter(size: 12)).foregroundColor(Color.mutedGray) }.padding(.horizontal, 12).padding(.vertical, 8).overlay(Rectangle().fill(Color.pillBorderGray).frame(height: 0.5), alignment: .bottom)
            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 3) { Text(isLang ? "WORD / PHRASE" : "ORIGINAL").font(.inter(size: 9, weight: .semibold)).foregroundColor(Color.mutedGray); Text(draft?.original ?? "").font(.inter(size: 12)).foregroundColor(Color.nearBlack).fixedSize(horizontal: false, vertical: true) }
                if vm.activeLectureMode == "international", let t = draft?.translation, !t.isEmpty { VStack(alignment: .leading, spacing: 3) { Text("TRANSLATION").font(.inter(size: 9, weight: .semibold)).foregroundColor(Color.mutedGray); Text(t).font(.inter(size: 12)).foregroundColor(Color.mediumGray).fixedSize(horizontal: false, vertical: true) } }
                VStack(alignment: .leading, spacing: 4) { Text("QUICK NOTE").font(.inter(size: 9, weight: .semibold)).foregroundColor(Color.mutedGray); TextField("Add a note…", text: $note, axis: .vertical).textFieldStyle(.plain).font(.inter(size: 12)).padding(8).background(Color.fillTertiary).cornerRadius(4).overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.pillBorderGray, lineWidth: 0.5)) }
                if !error.isEmpty { Text(error).font(.inter(size: 11)).foregroundColor(Color.accentRed) }
            }.padding(12)
            Spacer()
            HStack { Button("Cancel") { vm.activeCard = nil }.buttonStyle(.bordered); Spacer(); Button(saved ? "Saved ✓" : saving ? "Saving…" : "Save") { handle() }.buttonStyle(.borderedProminent).disabled(saved || saving) }.padding(.horizontal, 12).padding(.vertical, 8).overlay(Rectangle().fill(Color.pillBorderGray).frame(height: 0.5), alignment: .top)
        }.background(Color.white).cornerRadius(8).overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.pillBorderGray, lineWidth: 0.5)).shadow(color: .black.opacity(0.06), radius: 8, y: 1)
    }

    func handle() { guard let d = draft, !d.original.isEmpty else { error = "No text to save."; return }; saving = true; vm.confirmSave(draft: d, note: note.isEmpty ? nil : note); saved = true; DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { vm.activeCard = nil } }
}
