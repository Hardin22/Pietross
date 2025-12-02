import UIKit

protocol CanvasElementDelegate: AnyObject {
    func elementDidUpdate(id: UUID, newFrame: CGRect, newRotation: CGFloat)
    func elementDidRequestTextEdit(_ element: CanvasElementView)
}

class CanvasElementView: UIView, UIGestureRecognizerDelegate {
    
    let id: UUID
    let itemType: CanvasItem.ItemType
    weak var delegate: CanvasElementDelegate?
    
    private var imageView: UIImageView?
    private var label: UILabel?
    
    init(item: CanvasItem) {
        self.id = item.id
        self.itemType = item.type
        super.init(frame: item.frame)
        self.transform = CGAffineTransform(rotationAngle: item.rotation)
        
        setupContent(with: item)
        setupGestures()
        
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
            let lbl = UILabel(frame: bounds)
            lbl.text = item.textContent ?? "Testo"
            lbl.numberOfLines = 0
            lbl.font = .systemFont(ofSize: 24, weight: .medium)
            lbl.textAlignment = .center
            lbl.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            addSubview(lbl)
            self.label = lbl
            self.backgroundColor = .clear
        }
    }
    
    func updateText(_ text: String) {
        label?.text = text
    }
    
    private func setupGestures() {
        isUserInteractionEnabled = true
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        pan.delegate = self
        addGestureRecognizer(pan)
        
        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        pinch.delegate = self
        addGestureRecognizer(pinch)
        
        let rotate = UIRotationGestureRecognizer(target: self, action: #selector(handleRotate(_:)))
        rotate.delegate = self
        addGestureRecognizer(rotate)
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        addGestureRecognizer(tap)
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
    
    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard let superview = superview else { return }
        let translation = gesture.translation(in: superview)
        self.center = CGPoint(x: self.center.x + translation.x, y: self.center.y + translation.y)
        gesture.setTranslation(.zero, in: superview)
        if gesture.state == .ended { notifyUpdate() }
    }
    
    @objc private func handlePinch(_ gesture: UIPinchGestureRecognizer) {
        if gesture.state == .began || gesture.state == .changed {
            self.transform = self.transform.scaledBy(x: gesture.scale, y: gesture.scale)
            gesture.scale = 1.0
        }
        if gesture.state == .ended { notifyUpdate() }
    }
    
    @objc private func handleRotate(_ gesture: UIRotationGestureRecognizer) {
        if gesture.state == .began || gesture.state == .changed {
            self.transform = self.transform.rotated(by: gesture.rotation)
            gesture.rotation = 0
        }
        if gesture.state == .ended { notifyUpdate() }
    }
    
    @objc private func handleTap() {
        superview?.subviews.forEach { ($0 as? CanvasElementView)?.layer.borderWidth = 0 }
        self.layer.borderWidth = 2
        superview?.bringSubviewToFront(self)
        if itemType == .text { delegate?.elementDidRequestTextEdit(self) }
    }
    
    private func notifyUpdate() {
        let rotation = atan2(transform.b, transform.a)
        delegate?.elementDidUpdate(id: id, newFrame: frame, newRotation: rotation)
    }
}
