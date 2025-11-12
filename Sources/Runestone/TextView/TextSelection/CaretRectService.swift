import UIKit

final class CaretRectService {
    var stringView: StringView
    var lineManager: LineManager
    var textContainerInset: UIEdgeInsets = .zero {
        didSet {
            if textContainerInset != oldValue {
                invalidateCache()
            }
        }
    }
    var showLineNumbers = false {
        didSet {
            if showLineNumbers != oldValue {
                invalidateCache()
            }
        }
    }

    private let lineControllerStorage: LineControllerStorage
    private let gutterWidthService: GutterWidthService
    private var caretRectCache: [Int: CGRect] = [:]
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

        // Check cache for non-moving case
        if !allowMovingCaretToNextLineFragment, let cachedRect = caretRectCache[safeLocation] {
            return cachedRect
        }

        let line = lineManager.line(containingCharacterAt: safeLocation)!
        let lineController = lineControllerStorage.getOrCreateLineController(for: line)
        let lineLocalLocation = safeLocation - line.location
        if allowMovingCaretToNextLineFragment && shouldMoveCaretToNextLineFragment(forLocation: lineLocalLocation, in: line) {
            let rect = caretRect(at: location + 1, allowMovingCaretToNextLineFragment: false)
            return CGRect(x: leadingLineSpacing, y: rect.minY, width: rect.width, height: rect.height)
        } else {
            let localCaretRect = lineController.caretRect(atIndex: lineLocalLocation)
            let globalYPosition = line.yPosition + localCaretRect.minY
            let globalRect = CGRect(x: localCaretRect.minX, y: globalYPosition, width: localCaretRect.width, height: localCaretRect.height)
            let result = globalRect.offsetBy(dx: leadingLineSpacing, dy: textContainerInset.top)

            // Cache the result
            caretRectCache[safeLocation] = result
            return result
        }
    }

    func invalidateCache() {
        caretRectCache.removeAll(keepingCapacity: true)
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
