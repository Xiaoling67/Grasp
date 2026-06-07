import SwiftUI; import UniformTypeIdentifiers

// Spec: New Lecture — Name/Subject/Slides + Start Recording
struct NewLectureModalView: View {
    @EnvironmentObject var vm: AppViewModel; @State private var name = ""; @State private var subject = ""; @State private var slideURL: URL?; @State private var slideName: String?

    var body: some View {
        ZStack {
            Color.black.opacity(0.35).ignoresSafeArea().onTapGesture { vm.showNewLectureModal = false }
            VStack(spacing: 0) {
                HStack { Text("New Lecture").font(.inter(size: 15, weight: .semibold)).foregroundColor(Color(hex: "0A0A0A")); Spacer(); Button("×") { vm.showNewLectureModal = false }.buttonStyle(.plain).font(.inter(size: 14)).foregroundColor(Color(hex: "C0C0C0")) }.padding(.horizontal, 20).padding(.top, 16)
                VStack(spacing: 18) {
                    field("NAME (optional)", $name, "e.g. Macroeconomics Week 4")
                    field("SUBJECT (optional)", $subject, "e.g. Economics, Biology, History")
                    VStack(alignment: .leading, spacing: 6) { Text("SLIDES (optional · PDF or PPTX)").font(.inter(size: 11, weight: .semibold)).foregroundColor(Color(hex: "C0C0C0")).tracking(0.3); if let sn = slideName { HStack { Text(sn).font(.inter(size: 12)).foregroundColor(Color(hex: "5A5A5A")).lineLimit(1); Spacer(); Button("×") { slideURL = nil; slideName = nil }.buttonStyle(.plain).font(.inter(size: 14)).foregroundColor(Color(hex: "C0C0C0")) }.padding(7).background(Color(hex: "F8F8F8")).cornerRadius(4).overlay(RoundedRectangle(cornerRadius: 4).stroke(Color(hex: "E8E8E8"), lineWidth: 1)) } else { Button("Upload slides") { pick() }.font(.inter(size: 11)).padding(.horizontal, 10).padding(.vertical, 5).foregroundColor(Color(hex: "5A5A5A")).background(Color.clear).cornerRadius(980).overlay(RoundedRectangle(cornerRadius: 980).stroke(Color(hex: "E8E8E8"), lineWidth: 1)).buttonStyle(.plain).frame(maxWidth: .infinity) } }
                }.padding(20)
                HStack(spacing: 8) { Spacer(); Button("Cancel") { vm.showNewLectureModal = false }.font(.inter(size: 11)).padding(.horizontal, 10).padding(.vertical, 5).foregroundColor(Color(hex: "5A5A5A")).background(Color.clear).cornerRadius(980).overlay(RoundedRectangle(cornerRadius: 980).stroke(Color(hex: "E8E8E8"), lineWidth: 1)).buttonStyle(.plain); Button("Start Recording") { let m = DatabaseService.shared.getSetting(key: "defaultMode") ?? "standard"; Task { await vm.startLecture(name: name.isEmpty ? nil : name, mode: m, subject: subject.isEmpty ? nil : subject, slideURL: slideURL) } }.font(.inter(size: 11, weight: .medium)).foregroundColor(.white).padding(.horizontal, 12).padding(.vertical, 5).background(Color(hex: "1A5FD4")).cornerRadius(980).buttonStyle(.plain) }.padding(.horizontal, 20).padding(.vertical, 14).overlay(Rectangle().fill(Color(hex: "E8E8E8")).frame(height: 1), alignment: .top)
            }.frame(width: 420).background(Color.white).cornerRadius(12).shadow(color: .black.opacity(0.2), radius: 20, y: 8)
        }
    }

    func field(_ label: String, _ text: Binding<String>, _ placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 6) { Text(label).font(.inter(size: 11, weight: .semibold)).foregroundColor(Color(hex: "C0C0C0")).tracking(0.3); TextField(placeholder, text: text).textFieldStyle(.plain).font(.inter(size: 13)).foregroundColor(Color(hex: "0A0A0A")).padding(7).background(Color(hex: "F8F8F8")).cornerRadius(4).overlay(RoundedRectangle(cornerRadius: 4).stroke(Color(hex: "E8E8E8"), lineWidth: 1)) }
    }

    func pick() { let p = NSOpenPanel(); p.allowedContentTypes = [.pdf]; p.allowsMultipleSelection = false; if p.runModal() == .OK, let u = p.url { slideURL = u; slideName = u.lastPathComponent } }
}
