import SwiftUI

struct HomeView: View {
    @EnvironmentObject var vm: AppViewModel

    var body: some View {
        VStack {
            Spacer()
            VStack(spacing: 20) {
                Image(systemName: "waveform.circle.fill")
                    .font(.inter(size: 48))
                    .foregroundColor(.white.opacity(0.9))
                Text("New Lecture")
                    .font(.inter(size: 22, weight: .bold))
                    .foregroundColor(.white)
                Text("Real-time transcription with AI-powered notes and search")
                    .font(.inter(size: 14))
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                Button(action: { vm.showNewLectureModal = true }) {
                    Label("Start Recording", systemImage: "plus.circle.fill")
                        .font(.inter(size: 14, weight: .medium))
                        .foregroundColor(.accentColor)
                        .padding(.horizontal, 24).padding(.vertical, 12)
                        .background(Color.white)
                        .cornerRadius(12)
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, 48).padding(.horizontal, 40)
            .frame(maxWidth: 420)
            .background(
                LinearGradient(
                    colors: [Color(hex: "1A5FD4"), Color(hex: "4A8BFA")],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
            )
            .cornerRadius(16)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}
