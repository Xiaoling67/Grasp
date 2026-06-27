import SwiftUI

// Spec 12: Settings — Default Mode + Display
struct SettingsView: View {
    @EnvironmentObject var vm: AppViewModel; @State private var mode = "standard"; @State private var tl = "zh-CN"; @State private var fs = "medium"; @State private var st = true; @State private var hf = true
    @State private var showKnowledgeProfile = false; @State private var knownCount = 0

    var body: some View {
        ScrollView { VStack(alignment: .leading, spacing: 24) {
            Text("Settings").font(.inter(size: 16, weight: .semibold)).foregroundColor(Color.nearBlack)
            // Default Mode
            VStack(alignment: .leading, spacing: 12) { Text("Default Mode").font(.inter(size: 13, weight: .semibold)).foregroundColor(Color.nearBlack)
                HStack { Text("Lecture mode").font(.inter(size: 13)).foregroundColor(Color.mediumGray); Spacer(); Picker("", selection: $mode) { Text("Standard").tag("standard"); Text("International").tag("international") }.pickerStyle(.menu).frame(width: 160).onChange(of: mode) { DatabaseService.shared.setSetting(key: "defaultMode", value: mode) } }
                HStack { Text("Target language").font(.inter(size: 13)).foregroundColor(Color.mediumGray); Spacer(); TextField("e.g. zh-CN", text: $tl).textFieldStyle(.plain).font(.inter(size: 12)).multilineTextAlignment(.trailing).frame(width: 160) }
            }
            // Display
            VStack(alignment: .leading, spacing: 12) { Text("Display").font(.inter(size: 13, weight: .semibold)).foregroundColor(Color.nearBlack)
                HStack { Text("Font size").font(.inter(size: 13)).foregroundColor(Color.mediumGray); Spacer(); Picker("", selection: $fs) { Text("Small").tag("small"); Text("Medium").tag("medium"); Text("Large").tag("large") }.pickerStyle(.menu).frame(width: 160) }
                Toggle("Show translation", isOn: $st).font(.inter(size: 13)).foregroundColor(Color.mediumGray)
                Toggle("Hover to freeze scroll", isOn: $hf).font(.inter(size: 13)).foregroundColor(Color.mediumGray)
            }
            // Knowledge Profile
            Button(action: { showKnowledgeProfile = true }) {
                HStack {
                    Text("Knowledge Profile").font(.inter(size: 13)).foregroundColor(Color.nearBlack)
                    Spacer()
                    Text("\(knownCount) known").font(.inter(size: 11)).foregroundColor(Color.mutedGray)
                }
            }.buttonStyle(.plain)
            Spacer()
        }.padding(32).frame(maxWidth: 480) }
        .background(Color.white)
        .sheet(isPresented: $showKnowledgeProfile) { KnowledgeProfileView() }
        .onAppear { mode = DatabaseService.shared.getSetting(key: "defaultMode") ?? "standard"; tl = DatabaseService.shared.getSetting(key: "targetLanguage") ?? "zh-CN"; knownCount = MemoryService.shared.getKnownTerms().count }
    }
}
