import SwiftUI

// MARK: - Draggable Vertical Divider

struct VerticalDragHandle: View {
    @Binding var notesWidth: Double
    let availableWidth: CGFloat
    @State private var dragStartNotesWidth: Double?

    var body: some View {
        Rectangle()
            .fill(Color.clear)
            .frame(width: 6)
            .overlay(Rectangle().fill(Color.divider).frame(width: 2))
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if dragStartNotesWidth == nil {
                            dragStartNotesWidth = notesWidth
                        }
                        let start = dragStartNotesWidth ?? notesWidth
                        let minWidth = 240.0
                        let maxWidth = max(minWidth, Double(availableWidth) - 320.0)
                        notesWidth = max(minWidth, min(maxWidth, start - value.translation.width))
                    }
                    .onEnded { _ in
                        dragStartNotesWidth = nil
                    }
            )
            .onHover { hovering in
                if hovering { NSCursor.resizeLeftRight.push() }
                else { NSCursor.pop() }
            }
    }
}

// MARK: - Draggable Horizontal Divider

struct HorizontalDragHandle: View {
    @Binding var rowRatio: CGFloat
    let availableHeight: CGFloat
    @State private var dragStartRatio: CGFloat?

    var body: some View {
        Rectangle()
            .fill(Color.clear)
            .frame(height: 8)
            .overlay(Rectangle().fill(Color.divider).frame(height: 2))
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if dragStartRatio == nil {
                            dragStartRatio = rowRatio
                        }
                        let start = dragStartRatio ?? rowRatio
                        let totalHeight = max(1, availableHeight)
                        let ratio = max(0.30, min(0.80, (start * totalHeight + value.translation.height) / totalHeight))
                        rowRatio = ratio
                    }
                    .onEnded { _ in
                        dragStartRatio = nil
                    }
            )
            .onHover { hovering in
                if hovering { NSCursor.resizeUpDown.push() }
                else { NSCursor.pop() }
            }
    }
}
