import SwiftUI

// Spec 17: 3-step onboarding (Welcome → Mode → Done)
struct OnboardingModalView: View {
    @EnvironmentObject var vm: AppViewModel; @State private var step = 0; @State private var mode = "standard"

    var body: some View {
        ZStack {
            Color.black.opacity(0.35).ignoresSafeArea()
            VStack(spacing: 0) {
                HStack(spacing: 6) { ForEach(0..<3, id: \.self) { i in Circle().fill(i == step ? Color.aiNewBorder : i < step ? Color.lightBlueBorder : Color.pillBorderGray).frame(width: 6, height: 6) } }.padding(.top, 16)
                VStack(spacing: 12) {
                    switch step {
                    case 0: VStack(spacing: 8) { Text("Grasp").font(.inter(size: 24, weight: .bold)).foregroundColor(Color.nearBlack); Text("Welcome").font(.inter(size: 15, weight: .semibold)).foregroundColor(Color.nearBlack); Text("Your AI lecture companion. Real-time transcription, live translation, and AI-powered search — all in one place.").font(.inter(size: 13)).foregroundColor(Color.mediumGray).multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true) }
                    case 1: VStack(alignment: .leading, spacing: 12) { Text("Choose your default mode").font(.inter(size: 15, weight: .semibold)).foregroundColor(Color.nearBlack); Text("You can change this for each lecture.").font(.inter(size: 13)).foregroundColor(Color.mediumGray); HStack(spacing: 8) { modeBtn("Standard", "English only · No translation", tag: "standard"); modeBtn("International", "Live translation · Language saves", tag: "international") } }
                    default: VStack(spacing: 8) { Text("✓").font(.inter(size: 28)).foregroundColor(Color.aiNewBorder); Text("You're all set").font(.inter(size: 15, weight: .semibold)).foregroundColor(Color.nearBlack); Text("Click \"+ New Lecture\" to start.\n⌘⇧K to save · ⌘⇧E to search · ⌘⇧P to pause").font(.inter(size: 13)).foregroundColor(Color.mediumGray).multilineTextAlignment(.center) }
                    }
                }.padding(20).frame(minHeight: 200)

                HStack(spacing: 8) { if step > 0 && step < 2 { Button("Back") { step -= 1 }.font(.inter(size: 11)).padding(.horizontal, 10).padding(.vertical, 5).foregroundColor(Color.mediumGray).background(Color.clear).cornerRadius(980).overlay(RoundedRectangle(cornerRadius: 980).stroke(Color.pillBorderGray, lineWidth: 1)).buttonStyle(.plain) }; Spacer(); Button(step == 2 ? "Get started" : "Continue") { if step == 2 { vm.completeOnboarding(mode); return }; step += 1 }.font(.inter(size: 11, weight: .medium)).foregroundColor(.white).padding(.horizontal, 12).padding(.vertical, 5).background(Color.aiNewBorder).cornerRadius(980).buttonStyle(.plain) }.padding(.horizontal, 20).padding(.vertical, 14).overlay(Rectangle().fill(Color.pillBorderGray).frame(height: 1), alignment: .top)
            }.frame(width: 460).background(Color.white).cornerRadius(12).shadow(color: .black.opacity(0.2), radius: 20, y: 8)
        }
    }

    func modeBtn(_ title: String, _ desc: String, tag: String) -> some View {
        Button(action: { mode = tag }) { VStack(alignment: .leading, spacing: 3) { Text(title).font(.inter(size: 13, weight: .semibold)).foregroundColor(Color.nearBlack); Text(desc).font(.inter(size: 11)).foregroundColor(Color.textTertiary) }.padding(10).frame(maxWidth: .infinity, alignment: .leading).background(mode == tag ? Color.lightBlueBg : Color.white).cornerRadius(8).overlay(RoundedRectangle(cornerRadius: 8).stroke(mode == tag ? Color.aiNewBorder : Color.pillBorderGray, lineWidth: 1.5)) }.buttonStyle(.plain)
    }
}
