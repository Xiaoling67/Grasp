import SwiftUI

// Spec 17: 3-step onboarding (Welcome → Mode → Done)
struct OnboardingModalView: View {
    @EnvironmentObject var vm: AppViewModel; @State private var step = 0; @State private var mode = "standard"

    var body: some View {
        ZStack {
            Color.black.opacity(0.35).ignoresSafeArea()
            VStack(spacing: 0) {
                HStack(spacing: 6) { ForEach(0..<3, id: \.self) { i in Circle().fill(i == step ? Color(hex: "1A5FD4") : i < step ? Color(hex: "C5D8FC") : Color(hex: "E8E8E8")).frame(width: 6, height: 6) } }.padding(.top, 16)
                VStack(spacing: 12) {
                    switch step {
                    case 0: VStack(spacing: 8) { Text("Grasp").font(.inter(size: 24, weight: .bold)).foregroundColor(Color(hex: "0A0A0A")); Text("Welcome").font(.inter(size: 15, weight: .semibold)).foregroundColor(Color(hex: "0A0A0A")); Text("Your AI lecture companion. Real-time transcription, live translation, and AI-powered search — all in one place.").font(.inter(size: 13)).foregroundColor(Color(hex: "5A5A5A")).multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true) }
                    case 1: VStack(alignment: .leading, spacing: 12) { Text("Choose your default mode").font(.inter(size: 15, weight: .semibold)).foregroundColor(Color(hex: "0A0A0A")); Text("You can change this for each lecture.").font(.inter(size: 13)).foregroundColor(Color(hex: "5A5A5A")); HStack(spacing: 8) { modeBtn("Standard", "English only · No translation", tag: "standard"); modeBtn("International", "Live translation · Language saves", tag: "international") } }
                    default: VStack(spacing: 8) { Text("✓").font(.inter(size: 28)).foregroundColor(Color(hex: "1A5FD4")); Text("You're all set").font(.inter(size: 15, weight: .semibold)).foregroundColor(Color(hex: "0A0A0A")); Text("Click \"+ New Lecture\" to start.\n⌘⇧K to save · ⌘⇧E to search · ⌘⇧P to pause").font(.inter(size: 13)).foregroundColor(Color(hex: "5A5A5A")).multilineTextAlignment(.center) }
                    }
                }.padding(20).frame(minHeight: 200)

                HStack(spacing: 8) { if step > 0 && step < 2 { Button("Back") { step -= 1 }.font(.inter(size: 11)).padding(.horizontal, 10).padding(.vertical, 5).foregroundColor(Color(hex: "5A5A5A")).background(Color.clear).cornerRadius(980).overlay(RoundedRectangle(cornerRadius: 980).stroke(Color(hex: "E8E8E8"), lineWidth: 1)).buttonStyle(.plain) }; Spacer(); Button(step == 2 ? "Get started" : "Continue") { if step == 2 { vm.completeOnboarding(mode); return }; step += 1 }.font(.inter(size: 11, weight: .medium)).foregroundColor(.white).padding(.horizontal, 12).padding(.vertical, 5).background(Color(hex: "1A5FD4")).cornerRadius(980).buttonStyle(.plain) }.padding(.horizontal, 20).padding(.vertical, 14).overlay(Rectangle().fill(Color(hex: "E8E8E8")).frame(height: 1), alignment: .top)
            }.frame(width: 460).background(Color.white).cornerRadius(12).shadow(color: .black.opacity(0.2), radius: 20, y: 8)
        }
    }

    func modeBtn(_ title: String, _ desc: String, tag: String) -> some View {
        Button(action: { mode = tag }) { VStack(alignment: .leading, spacing: 3) { Text(title).font(.inter(size: 13, weight: .semibold)).foregroundColor(Color(hex: "0A0A0A")); Text(desc).font(.inter(size: 11)).foregroundColor(Color(hex: "9A9A9A")) }.padding(10).frame(maxWidth: .infinity, alignment: .leading).background(mode == tag ? Color(hex: "E8F0FE") : Color.white).cornerRadius(8).overlay(RoundedRectangle(cornerRadius: 8).stroke(mode == tag ? Color(hex: "1A5FD4") : Color(hex: "E8E8E8"), lineWidth: 1.5)) }.buttonStyle(.plain)
    }
}
