import UIKit

final class CaretRectService {
    var stringView: StringView
    var lineManager: LineManager
    var textContainerInset: UIEdgeInsets = .zero
    var showLineNumbers = false

    private let lineControllerStorage: LineControllerStorage
    private let gutterWidthService: GutterWidthService
    private var leadingLineSpacing: CGFloat {
        if showLineNumbers {
            return gutterWidthService.gutterWidth + textContainerInset.left
        } else {
            return textContainerInset.left
        }
    }

    init(stringView: StringView,
         lineManager: LineManager,
         lineControllerStorage: LineControllerStorage,
         gutterWidthService: GutterWidthService) {
        self.stringView = stringView
        self.lineManager = lineManager
        self.lineControllerStorage = lineControllerStorage
        self.gutterWidthService = gutterWidthService
    }

    func caretRect(at location: Int, allowMovingCaretToNextLineFragment: Bool) -> CGRect {
        let safeLocation = min(max(location, 0), stringView.string.length)
        let line = lineManager.line(containingCharacterAt: safeLocation)!
        // Pre-fetch location and yPosition to avoid multiple tree traversals
        let lineLocation = line.location
        let lineYPosition = line.yPosition
        return caretRect(
            at: location,
            allowMovingCaretToNextLineFragment: allowMovingCaretToNextLineFragment,
            cachedLine: line,
            cachedLineLocation: lineLocation,
            cachedLineYPosition: lineYPosition
        )
    }

    /// Optimized version that accepts pre-fetched line data to avoid redundant tree traversals.
    /// Use this when computing multiple caret rects to avoid O(log n) tree walks for each call.
    func caretRect(
        at location: Int,
        allowMovingCaretToNextLineFragment: Bool,
        cachedLine: DocumentLineNode,
        cachedLineLocation: Int,
        cachedLineYPosition: CGFloat
    ) -> CGRect {
        let safeLocation = min(max(location, 0), stringView.string.length)
        let lineController = lineControllerStorage.getOrCreateLineController(for: cachedLine)
        let lineLocalLocation = safeLocation - cachedLineLocation
        if allowMovingCaretToNextLineFragment && shouldMoveCaretToNextLineFragment(forLocation: lineLocalLocation, in: cachedLine) {
            let rect = caretRect(at: location + 1, allowMovingCaretToNextLineFragment: false)
            return CGRect(x: leadingLineSpacing, y: rect.minY, width: rect.width, height: rect.height)
        } else {
            let localCaretRect = lineController.caretRect(atIndex: lineLocalLocation)
            let globalYPosition = cachedLineYPosition + localCaretRect.minY
            let globalRect = CGRect(x: localCaretRect.minX, y: globalYPosition, width: localCaretRect.width, height: localCaretRect.height)
            return globalRect.offsetBy(dx: leadingLineSpacing, dy: textContainerInset.top)
        }
    }
}

private extension CaretRectService {
    private func shouldMoveCaretToNextLineFragment(forLocation location: Int, in line: DocumentLineNode) -> Bool {
        let lineController = lineControllerStorage.getOrCreateLineController(for: line)
        guard lineController.numberOfLineFragments > 0 else {
            return false
        }
        guard let lineFragmentNode = lineController.lineFragmentNode(containingCharacterAt: location) else {
            return false
        }
        guard lineFragmentNode.index > 0 else {
            return false
        }
        return location == lineFragmentNode.data.lineFragment?.range.location
    }
}
