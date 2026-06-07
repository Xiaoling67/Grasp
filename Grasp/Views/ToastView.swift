import SwiftUI

// Spec 22: Toast — bottom center, pill shape
struct ToastView: View {
    let message: String; let type: String
    var body: some View {
        Text(message).font(.inter(size: 12, weight: .medium)).foregroundColor(.white)
            .padding(.horizontal, 18).padding(.vertical, 10)
            .background(type == "error" ? Color(hex: "B91C1C") : type == "success" ? Color(hex: "15803D") : Color(hex: "0A0A0A"))
            .cornerRadius(980).shadow(color: .black.opacity(0.15), radius: 20, y: 4)
            .frame(maxWidth: .infinity, alignment: .bottom).padding(.bottom, 24)
    }
}
