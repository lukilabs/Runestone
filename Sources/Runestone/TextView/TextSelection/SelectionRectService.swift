import UIKit

final class SelectionRectService {
    var lineManager: LineManager
    var textContainerInset: UIEdgeInsets = .zero
    var lineHeightMultiplier: CGFloat = 1

    private let contentSizeService: ContentSizeService
    private let gutterWidthService: GutterWidthService
    private let caretRectService: CaretRectService

    init(lineManager: LineManager,
         contentSizeService: ContentSizeService,
         gutterWidthService: GutterWidthService,
         caretRectService: CaretRectService) {
        self.lineManager = lineManager
        self.contentSizeService = contentSizeService
        self.gutterWidthService = gutterWidthService
        self.caretRectService = caretRectService
    }

    func selectionRects(in range: NSRange) -> [TextSelectionRect] {
        guard range.length > 0 else {
            return []
        }
        guard let endLine = lineManager.line(containingCharacterAt: range.upperBound) else {
            return []
        }
        let leadingLineSpacing = gutterWidthService.gutterWidth + textContainerInset.left
        // Pre-fetch endLine.location once to avoid multiple tree traversals
        let endLineLocation = endLine.location
        let selectsLineEnding = range.upperBound == endLineLocation
        let adjustedRange = NSRange(location: range.location, length: selectsLineEnding ? range.length - 1 : range.length)

        // Pre-fetch start line data to avoid redundant tree traversals
        guard let startLine = lineManager.line(containingCharacterAt: adjustedRange.lowerBound) else {
            return []
        }
        let startLineLocation = startLine.location
        let startLineYPosition = startLine.yPosition

        let startCaretRect = caretRectService.caretRect(
            at: adjustedRange.lowerBound,
            allowMovingCaretToNextLineFragment: true,
            cachedLine: startLine,
            cachedLineLocation: startLineLocation,
            cachedLineYPosition: startLineYPosition
        )

        // For end caret, check if it's on the same line to reuse cached data
        let endCaretRect: CGRect
        if startLine === endLine || (adjustedRange.upperBound >= startLineLocation && adjustedRange.upperBound < startLineLocation + startLine.value) {
            // End position is on the same line as start, reuse cached line data
            endCaretRect = caretRectService.caretRect(
                at: adjustedRange.upperBound,
                allowMovingCaretToNextLineFragment: false,
                cachedLine: startLine,
                cachedLineLocation: startLineLocation,
                cachedLineYPosition: startLineYPosition
            )
        } else {
            // End position is on a different line, need to look up end line
            // Check if we can reuse the already-fetched endLine
            if adjustedRange.upperBound >= endLineLocation && adjustedRange.upperBound < endLineLocation + endLine.value {
                let endLineYPosition = endLine.yPosition
                endCaretRect = caretRectService.caretRect(
                    at: adjustedRange.upperBound,
                    allowMovingCaretToNextLineFragment: false,
                    cachedLine: endLine,
                    cachedLineLocation: endLineLocation,
                    cachedLineYPosition: endLineYPosition
                )
            } else {
                // Adjusted upper bound is on a different line than endLine, fetch the correct line
                guard let adjustedEndLine = lineManager.line(containingCharacterAt: adjustedRange.upperBound) else {
                    return []
                }
                let adjustedEndLineLocation = adjustedEndLine.location
                let adjustedEndLineYPosition = adjustedEndLine.yPosition
                endCaretRect = caretRectService.caretRect(
                    at: adjustedRange.upperBound,
                    allowMovingCaretToNextLineFragment: false,
                    cachedLine: adjustedEndLine,
                    cachedLineLocation: adjustedEndLineLocation,
                    cachedLineYPosition: adjustedEndLineYPosition
                )
            }
        }

        let fullWidth = max(contentSizeService.contentWidth, contentSizeService.scrollViewWidth) - leadingLineSpacing - textContainerInset.right
        if startCaretRect.minY == endCaretRect.minY && startCaretRect.maxY == endCaretRect.maxY {
            // Selecting text in the same line fragment.
            let width = selectsLineEnding ? fullWidth - (startCaretRect.minX - leadingLineSpacing) : endCaretRect.maxX - startCaretRect.maxX
            let scaledHeight = startCaretRect.height * lineHeightMultiplier
            let offsetY = startCaretRect.minY - (scaledHeight - startCaretRect.height) / 2
            let rect = CGRect(x: startCaretRect.minX, y: offsetY, width: width, height: scaledHeight)
            let selectionRect = TextSelectionRect(rect: rect, writingDirection: .natural, containsStart: true, containsEnd: true)
            return [selectionRect]
        } else {
            // Selecting text across line fragments and possibly across lines.
            let startWidth = fullWidth - (startCaretRect.minX - leadingLineSpacing)
            let startScaledHeight = startCaretRect.height * lineHeightMultiplier
            let startOffsetY = startCaretRect.minY - (startScaledHeight - startCaretRect.height) / 2
            let startRect = CGRect(x: startCaretRect.minX, y: startOffsetY, width: startWidth, height: startScaledHeight)
            let endWidth = selectsLineEnding ? fullWidth : endCaretRect.minX - leadingLineSpacing
            let endScaledHeight = endCaretRect.height * lineHeightMultiplier
            let endOffsetY = endCaretRect.minY - (endScaledHeight - endCaretRect.height) / 2
            let endRect = CGRect(x: leadingLineSpacing, y: endOffsetY, width: endWidth, height: endScaledHeight)
            let middleHeight = endRect.minY - startRect.maxY
            let middleRect = CGRect(x: leadingLineSpacing, y: startRect.maxY, width: fullWidth, height: middleHeight)
            let startSelectionRect = TextSelectionRect(rect: startRect, writingDirection: .natural, containsStart: true, containsEnd: false)
            let middleSelectionRect = TextSelectionRect(rect: middleRect, writingDirection: .natural, containsStart: false, containsEnd: false)
            let endSelectionRect = TextSelectionRect(rect: endRect, writingDirection: .natural, containsStart: false, containsEnd: true)
            return [startSelectionRect, middleSelectionRect, endSelectionRect]
        }
    }
}
