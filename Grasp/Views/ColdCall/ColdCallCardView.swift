import SwiftUI

// Spec 14: Cold call card — 3 states, 45s auto-dismiss
struct ColdCallCardView: View {
    @EnvironmentObject var vm: AppViewModel; let phase: ColdCallPhase

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack { Text("✋ Cold Call").font(.inter(size: 11, weight: .semibold)).foregroundColor(Color(hex: "F59E0B")); Spacer(); Button("✕") { vm.dismissCC() }.buttonStyle(.plain).font(.inter(size: 12)).foregroundColor(Color(hex: "C0C0C0")) }
            switch phase {
            case .detected(let q):
                Text("\"\(q)\"").font(.inter(size: 12)).italic().foregroundColor(Color(hex: "0A0A0A")).fixedSize(horizontal: false, vertical: true)
                Button("Generate Answer") { Task { await vm.generateCCAnswer(q: q) } }.font(.inter(size: 11, weight: .medium)).foregroundColor(.white).padding(.horizontal, 14).padding(.vertical, 6).background(Color(hex: "1A5FD4")).cornerRadius(980).buttonStyle(.plain)
            case .generating: HStack(spacing: 8) { ForEach(0..<3, id: \.self) { i in Circle().fill(Color(hex: "E8E8E8")).frame(width: 6, height: 6) }; Text("Generating answer…").font(.inter(size: 12)).foregroundColor(Color(hex: "5A5A5A")) }
            case .answered(let a):
                Text(typeLabel(a.questionType)).font(.inter(size: 10, weight: .medium)).foregroundColor(Color(hex: "1A5FD4")).padding(.horizontal, 6).padding(.vertical, 2).background(Color(hex: "E8F0FE")).cornerRadius(4)
                Text(a.shortAnswer).font(.inter(size: 12)).foregroundColor(Color(hex: "0A0A0A")).fixedSize(horizontal: false, vertical: true)
                ForEach(a.supportingPoints, id: \.self) { p in HStack(alignment: .top, spacing: 6) { Text("•").font(.inter(size: 11)).foregroundColor(Color(hex: "5A5A5A")); Text(p).font(.inter(size: 11)).foregroundColor(Color(hex: "5A5A5A")).fixedSize(horizontal: false, vertical: true) } }
                HStack(spacing: 8) {
                    Button("Save to Notes") { vm.saveCCToNotes(answer: a) }
                        .font(.inter(size: 11, weight: .medium)).foregroundColor(Color(hex: "15803D"))
                        .padding(.horizontal, 12).padding(.vertical, 5)
                        .background(Color(hex: "F0FDF4")).cornerRadius(980).buttonStyle(.plain)
                    Spacer()
                }
            }
        }.padding(14).background(Color.white).cornerRadius(10).overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(hex: "FBBF24"), lineWidth: 1)).shadow(color: .black.opacity(0.06), radius: 12, y: 4)
    }
    func typeLabel(_ t: String) -> String { ["Concept Explanation":"Concept","Applied Analysis":"Analysis","Opinion Expression":"Opinion","Recall":"Recall"][t] ?? t }
}

// Compact banner variant for the Explain tab — amber left border, no card container
struct ColdCallBanner: View {
    @EnvironmentObject var vm: AppViewModel; let phase: ColdCallPhase

    var body: some View {
        HStack(spacing: 8) {
            Rectangle().fill(Color(hex: "FBBF24")).frame(width: 3)
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("✋ Cold Call").font(.inter(size: 11, weight: .semibold)).foregroundColor(Color(hex: "F59E0B"))
                    Spacer()
                    Button("✕") { vm.dismissCC() }.buttonStyle(.plain).font(.inter(size: 12)).foregroundColor(Color(hex: "C0C0C0"))
                }
                switch phase {
                case .detected(let q):
                    Text("\"\(q)\"").font(.inter(size: 12)).italic().foregroundColor(Color(hex: "0A0A0A")).fixedSize(horizontal: false, vertical: true)
                    Button("Generate Answer") { Task { await vm.generateCCAnswer(q: q) } }
                        .font(.inter(size: 11, weight: .medium)).foregroundColor(.white)
                        .padding(.horizontal, 14).padding(.vertical, 6).background(Color(hex: "1A5FD4")).cornerRadius(980).buttonStyle(.plain)
                case .generating:
                    HStack(spacing: 8) {
                        ForEach(0..<3, id: \.self) { i in Circle().fill(Color(hex: "E8E8E8")).frame(width: 6, height: 6) }
                        Text("Generating answer…").font(.inter(size: 12)).foregroundColor(Color(hex: "5A5A5A"))
                    }
                case .answered(let a):
                    Text(typeLabel(a.questionType)).font(.inter(size: 10, weight: .medium)).foregroundColor(Color(hex: "1A5FD4"))
                        .padding(.horizontal, 6).padding(.vertical, 2).background(Color(hex: "E8F0FE")).cornerRadius(4)
                    Text(a.shortAnswer).font(.inter(size: 12)).foregroundColor(Color(hex: "0A0A0A")).fixedSize(horizontal: false, vertical: true)
                    ForEach(a.supportingPoints, id: \.self) { p in
                        HStack(alignment: .top, spacing: 6) {
                            Text("•").font(.inter(size: 11)).foregroundColor(Color(hex: "5A5A5A"))
                            Text(p).font(.inter(size: 11)).foregroundColor(Color(hex: "5A5A5A")).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    Button("Save to Notes") { vm.saveCCToNotes(answer: a) }
                        .font(.inter(size: 11, weight: .medium)).foregroundColor(Color(hex: "15803D"))
                        .padding(.horizontal, 12).padding(.vertical, 5).background(Color(hex: "F0FDF4")).cornerRadius(980).buttonStyle(.plain)
                }
            }.padding(10)
        }.background(Color(hex: "FFFBEB")).cornerRadius(8)
    }

    func typeLabel(_ t: String) -> String {
        ["Concept Explanation":"Concept","Applied Analysis":"Analysis","Opinion Expression":"Opinion","Recall":"Recall"][t] ?? t
    }
}
