import UIKit

protocol CanvasElementDelegate: AnyObject {
    func elementDidUpdate(id: UUID, newFrame: CGRect, newRotation: CGFloat)
    func elementDidRequestTextEdit(_ element: CanvasElementView)
    func elementDidRequestDelete(_ element: CanvasElementView)
}

class CanvasElementView: UIView, UIGestureRecognizerDelegate {
    
    let id: UUID
    let itemType: CanvasItem.ItemType
    weak var delegate: CanvasElementDelegate?
    
    private var imageView: UIImageView?
    private var resizeHandle: UIView?
    private var deleteButton: UIButton?
    
    init(item: CanvasItem) {
        self.id = item.id
        self.itemType = item.type
        super.init(frame: item.frame)
        self.transform = CGAffineTransform(rotationAngle: item.rotation)
        
        setupContent(with: item)
        setupGestures()
        setupResizeHandle()
        setupDeleteButton()
        
        self.layer.borderColor = UIColor.systemBlue.cgColor
        self.layer.borderWidth = 0
    }
    
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    private func setupContent(with item: CanvasItem) {
        switch item.type {
        case .image:
            let imgView = UIImageView(frame: bounds)
            if let data = item.imageData {
                imgView.image = UIImage(data: data)
            }
            imgView.contentMode = .scaleAspectFill
            imgView.clipsToBounds = true
            imgView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            addSubview(imgView)
            self.imageView = imgView
            
        case .text:
            // Deprecated in new design, but kept for compatibility
            let lbl = UILabel(frame: bounds)
            lbl.text = item.textContent ?? "Testo"
            lbl.numberOfLines = 0
            lbl.font = .systemFont(ofSize: 24, weight: .medium)
            lbl.textAlignment = .center
            lbl.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            addSubview(lbl)
            self.backgroundColor = .clear
        }
    }
    
    private var initialBounds: CGRect = .zero
    private var initialCenter: CGPoint = .zero
    private var initialTransform: CGAffineTransform = .identity
    private var aspectRatio: CGFloat = 1.0

    func updateText(_ text: String) {
        // Deprecated
    }
    
    private func setupGestures() {
        isUserInteractionEnabled = true
        
        // Dragging
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        pan.delegate = self
        addGestureRecognizer(pan)
        
        // Rotation
        let rotate = UIRotationGestureRecognizer(target: self, action: #selector(handleRotate(_:)))
        rotate.delegate = self
        addGestureRecognizer(rotate)
        
        // Selection
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        addGestureRecognizer(tap)
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        // Don't allow simultaneous pan (drag) and resize pan
        if let view = gestureRecognizer.view, view == resizeHandle {
            return false
        }
        return true
    }
    
    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard let superview = superview else { return }
        let translation = gesture.translation(in: superview)
        self.center = CGPoint(x: self.center.x + translation.x, y: self.center.y + translation.y)
        gesture.setTranslation(.zero, in: superview)
        if gesture.state == .ended { notifyUpdate() }
    }
    
    @objc private func handleRotate(_ gesture: UIRotationGestureRecognizer) {
        if gesture.state == .began || gesture.state == .changed {
            self.transform = self.transform.rotated(by: gesture.rotation)
            gesture.rotation = 0
        }
        if gesture.state == .ended { notifyUpdate() }
    }

    var isSelected: Bool = false

    func deselect() {
        isSelected = false
        self.layer.borderWidth = 0
        self.resizeHandle?.isHidden = true
        self.deleteButton?.isHidden = true
    }

    private func setupDeleteButton() {
        let btnSize: CGFloat = 50 // Larger button
        let btn = UIButton(frame: CGRect(x: -btnSize/2, y: -btnSize/2, width: btnSize, height: btnSize))
        btn.backgroundColor = .systemRed
        btn.setImage(UIImage(systemName: "trash.fill"), for: .normal)
        btn.tintColor = .white
        btn.layer.cornerRadius = btnSize / 2
        btn.isHidden = true
        btn.addTarget(self, action: #selector(handleDelete), for: .touchUpInside)
        addSubview(btn)
        self.deleteButton = btn
    }
    
    @objc private func handleDelete() {
        delegate?.elementDidRequestDelete(self)
    }

    private func setupResizeHandle() {
        let handleSize: CGFloat = 80 // Much larger touch area
        // Center the handle on the bottom-right corner
        let handle = UIView(frame: CGRect(x: bounds.width - handleSize/2, y: bounds.height - handleSize/2, width: handleSize, height: handleSize))
        
        // Visual indicator (larger)
        let dotSize: CGFloat = 24
        let visualDot = UIView(frame: CGRect(x: (handleSize - dotSize)/2, y: (handleSize - dotSize)/2, width: dotSize, height: dotSize))
        visualDot.backgroundColor = .systemBlue
        visualDot.layer.cornerRadius = dotSize / 2
        visualDot.isUserInteractionEnabled = false
        handle.addSubview(visualDot)
        
        handle.backgroundColor = .clear // Transparent touch area
        handle.autoresizingMask = [.flexibleLeftMargin, .flexibleTopMargin]
        handle.isHidden = true
        addSubview(handle)
        self.resizeHandle = handle
        
        let resizePan = UIPanGestureRecognizer(target: self, action: #selector(handleResizePan(_:)))
        handle.addGestureRecognizer(resizePan)
    }

    @objc private func handleResizePan(_ gesture: UIPanGestureRecognizer) {
        guard let superview = superview else { return }
        
        if gesture.state == .began {
            initialBounds = self.bounds
            initialCenter = self.center
            initialTransform = self.transform
            aspectRatio = initialBounds.width / initialBounds.height
        }
        
        // Get translation in the view's LOCAL coordinate system (unrotated)
        // Since the handle is a subview, we can ask for translation in 'self'
        let translation = gesture.translation(in: self)
        
        // Calculate new dimensions maintaining aspect ratio
        // We use the larger component of translation to drive the resize
        let delta = max(translation.x, translation.y)
        
        let newWidth = max(50, initialBounds.width + delta)
        let newHeight = newWidth / aspectRatio
        
        let widthChange = newWidth - initialBounds.width
        let heightChange = newHeight - initialBounds.height
        
        // Apply new bounds
        self.bounds = CGRect(origin: .zero, size: CGSize(width: newWidth, height: newHeight))
        
        // Adjust center to anchor top-left corner
        // When bounds increase by (dw, dh), the center shifts by (dw/2, dh/2) in local space relative to top-left.
        // We need to move the actual center by this amount, rotated by the view's transform.
        
        let angle = atan2(initialTransform.b, initialTransform.a)
        let cosA = cos(angle)
        let sinA = sin(angle)
        
        let offsetX = widthChange / 2
        let offsetY = heightChange / 2
        
        let rotatedOffsetX = offsetX * cosA - offsetY * sinA
        let rotatedOffsetY = offsetX * sinA + offsetY * cosA
        
        self.center = CGPoint(
            x: initialCenter.x + rotatedOffsetX,
            y: initialCenter.y + rotatedOffsetY
        )
        
        if gesture.state == .ended { notifyUpdate() }
    }
    
    @objc private func handleTap() {
        // Deselect others
        superview?.subviews.forEach {
            if let element = $0 as? CanvasElementView {
                element.deselect()
            }
        }
        
        // Select self
        isSelected = true
        self.layer.borderWidth = 2
        self.resizeHandle?.isHidden = false
        self.deleteButton?.isHidden = false
        superview?.bringSubviewToFront(self)
        
        if itemType == .text { delegate?.elementDidRequestTextEdit(self) }
    }
    
    private func notifyUpdate() {
        let rotation = atan2(transform.b, transform.a)
        delegate?.elementDidUpdate(id: id, newFrame: frame, newRotation: rotation)
    }
}
