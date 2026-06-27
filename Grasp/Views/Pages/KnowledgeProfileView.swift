import SwiftUI

// Spec 4.3: Knowledge Profile Editor
struct KnowledgeProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var records = [KnowledgeRecord]()
    @State private var knownCount = 0
    @State private var newConcept = ""
    @State private var validationMessage = ""
    @State private var showClearAlert = false

    private let ms = MemoryService.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Button(action: { dismiss() }) {
                    HStack(spacing: 4) {
                        Text("<").font(.inter(size: 13, weight: .semibold)).foregroundColor(Color.aiNewBorder)
                        Text("Back").font(.inter(size: 13)).foregroundColor(Color.aiNewBorder)
                    }
                }.buttonStyle(.plain)
                Spacer()
                Text("Knowledge Profile").font(.inter(size: 16, weight: .semibold)).foregroundColor(Color.nearBlack)
                Spacer()
                Text("\(knownCount) known").font(.inter(size: 11)).foregroundColor(Color.mutedGray)
            }
            .padding(EdgeInsets(top: 20, leading: 24, bottom: 12, trailing: 24))

            Divider().foregroundColor(Color.pillBorderGray)

            // Add concept row
            HStack(spacing: 8) {
                TextField("Type a concept you know\u{2026}", text: $newConcept)
                    .textFieldStyle(.plain)
                    .font(.inter(size: 13))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.hoverBg)
                    .cornerRadius(6)
                    .onSubmit { addConcept() }

                Button("+ Add") { addConcept() }
                    .font(.inter(size: 12, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(Color.aiNewBorder)
                    .cornerRadius(6)
                    .buttonStyle(.plain)
            }
            .padding(EdgeInsets(top: 12, leading: 24, bottom: 4, trailing: 24))

            // Validation message
            if !validationMessage.isEmpty {
                Text(validationMessage)
                    .font(.inter(size: 11))
                    .foregroundColor(.red)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 4)
            }

            // Records list
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    let grouped = groupByStatus()
                    let sections: [(KnowledgeStatus, [KnowledgeRecord])] = [
                        (.known, grouped[.known] ?? []),
                        (.lookedUp, grouped[.lookedUp] ?? []),
                        (.dismissed, grouped[.dismissed] ?? []),
                        (.preventive, grouped[.preventive] ?? []),
                    ]

                    ForEach(Array(sections.enumerated()), id: \.offset) { _, section in
                        let (status, items) = section
                        if !items.isEmpty {
                            SectionHeader(title: status.displayName, count: items.count)
                            ForEach(items) { record in
                                KnowledgeRecordRow(record: record, onDelete: { deleteRecord(record) })
                            }
                        }
                    }

                    if records.isEmpty {
                        VStack(spacing: 8) {
                            Text("No concepts yet")
                                .font(.inter(size: 13))
                                .foregroundColor(Color.mutedGray)
                                .padding(.top, 40)
                            Text("Concepts you search, save, or dismiss will appear here.")
                                .font(.inter(size: 11))
                                .foregroundColor(Color.veryLightGray)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                        }
                        .frame(maxWidth: .infinity)
                    }

                    // Clear All button
                    if !records.isEmpty {
                        Button(action: { showClearAlert = true }) {
                            HStack {
                                Spacer()
                                Text("Clear All History")
                                    .font(.inter(size: 12, weight: .medium))
                                    .foregroundColor(.red)
                                Spacer()
                            }
                            .padding(.vertical, 12)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 24)
                        .padding(.top, 12)
                    }
                }
                .padding(.bottom, 24)
            }
        }
        .frame(width: 480, height: 520)
        .background(Color.white)
        .onAppear(perform: loadData)
        .alert("Clear All Knowledge History?", isPresented: $showClearAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Clear All", role: .destructive) { clearAll() }
        } message: {
            Text("This removes all concepts you've searched, saved, or dismissed.")
        }
    }

    // MARK: - Data

    private func loadData() {
        records = ms.getAllRecords()
        knownCount = ms.getKnownTerms().count
    }

    private func groupByStatus() -> [KnowledgeStatus: [KnowledgeRecord]] {
        Dictionary(grouping: records, by: { $0.status })
    }

    // MARK: - Actions

    private func addConcept() {
        let trimmed = newConcept.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            validationMessage = "Enter a concept name"
            return
        }
        guard trimmed.count >= 2 else {
            validationMessage = "Enter a concept name (at least 2 characters)"
            return
        }
        validationMessage = ""
        ms.addManualConcept(trimmed)
        newConcept = ""
        loadData()
    }

    private func deleteRecord(_ record: KnowledgeRecord) {
        ms.deleteRecord(concept: record.concept)
        loadData()
    }

    private func clearAll() {
        ms.recordInteraction(concept: "", action: .clearHistory)
        loadData()
    }
}

// MARK: - Section Header
private struct SectionHeader: View {
    let title: String
    let count: Int

    var body: some View {
        HStack {
            Text("\u{2500}\u{2500} \(title) (\(count)) \u{2500}\u{2500}")
                .font(.inter(size: 11, weight: .medium))
                .foregroundColor(Color.mutedGray)
            Spacer()
        }
        .padding(EdgeInsets(top: 16, leading: 24, bottom: 6, trailing: 24))
    }
}

// MARK: - Knowledge Record Row
private struct KnowledgeRecordRow: View {
    let record: KnowledgeRecord
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            // Concept name
            Text(record.concept.prefix(1).uppercased() + record.concept.dropFirst())
                .font(.inter(size: 13))
                .foregroundColor(Color.nearBlack)
                .lineLimit(1)

            Spacer()

            // Status badge
            Text(statusDisplayText)
                .font(.inter(size: 10, weight: .medium))
                .foregroundColor(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(statusColor)
                .cornerRadius(4)

            // Search count badge (for looked_up/preventive)
            if record.status == .lookedUp || record.status == .preventive {
                Text("\u{00D7}\(record.searchCount)")
                    .font(.inter(size: 10))
                    .foregroundColor(Color.searchCountGray)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color.badgeBgGray)
                    .cornerRadius(4)
            }

            // Delete button
            Button(action: onDelete) {
                Text("\u{00D7}")
                    .font(.inter(size: 13, weight: .medium))
                    .foregroundColor(Color.mutedGray)
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(.plain)
        }
        .padding(EdgeInsets(top: 6, leading: 24, bottom: 6, trailing: 24))
        .background(Color.white)
    }

    private var statusDisplayText: String {
        switch record.status {
        case .known:      return "\u{2713}"
        case .lookedUp:   return "\u{25C9}"
        case .dismissed:  return "\u{2611}"
        case .preventive: return "\u{26A0}"
        case .neverSeen:  return "?"
        }
    }

    private var statusColor: Color {
        switch record.status {
        case .known:      return Color.statusGreen // green
        case .lookedUp:   return Color.statusBlue // blue
        case .dismissed:  return Color.statusGray // grey
        case .preventive: return Color.statusOrange // orange
        case .neverSeen:  return Color.mutedGray // light grey
        }
    }
}
