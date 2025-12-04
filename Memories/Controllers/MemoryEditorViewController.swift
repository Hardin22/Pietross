import UIKit
import PencilKit
import PhotosUI

class MemoryEditorViewController: UIViewController, PKCanvasViewDelegate, CanvasElementDelegate, UITextViewDelegate {
    
    private let viewModel: EditorViewModel
    private var isEditable: Bool
    
    // UI Elements
    private let pageContainerView = UIView()
    private let backgroundImageView = UIImageView() // New background image view
    private let bodyTextView = UITextView() // New standard text editor
    private let objectsLayer = PassThroughView()
    private let canvasView = PKCanvasView()
    private let toolPicker = PKToolPicker()
    
    private var isiPad: Bool {
        return UIDevice.current.userInterfaceIdiom == .pad
    }
    
    private var isDrawingMode = true {
        didSet { updateInputMode() }
    }
    
    private enum ColorPickerMode {
        case text
        case background
    }
    
    private var activeColorPickerMode: ColorPickerMode = .text
    
    // Formatting State
    private var currentFont: UIFont = .systemFont(ofSize: 18)
    private var currentTextColor: UIColor = .black
    
    // Toolbar
    private let editorToolbar = EditorToolbarView()
    
    init(viewModel: EditorViewModel, isEditable: Bool = true) {
        self.viewModel = viewModel
        self.isEditable = isEditable
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupBindings()
        
        if !isEditable {
            isDrawingMode = false
            canvasView.isUserInteractionEnabled = false
            objectsLayer.isUserInteractionEnabled = false
            bodyTextView.isEditable = false
        } else {
            updateInputMode()
        }
        
        if isiPad {
            viewModel.restoreDrawing()
        }
        refreshObjectsLayer()
        if let attributedText = viewModel.getAttributedBodyText() {
            bodyTextView.attributedText = attributedText
        } else {
            bodyTextView.text = viewModel.pageData.bodyText
            bodyTextView.font = .systemFont(ofSize: 18) // Default font if no attributed text
        }
        
        // Load background
        pageContainerView.backgroundColor = viewModel.getBackgroundColor()
        if let bgName = viewModel.getBackgroundImageName() {
            backgroundImageView.image = UIImage(named: bgName)
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        fitPageToScreen()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if isEditable, isiPad, let window = view.window {
            toolPicker.setVisible(true, forFirstResponder: canvasView)
            toolPicker.addObserver(canvasView)
            canvasView.becomeFirstResponder()
        }
    }
    
    private func setupUI() {
        view.backgroundColor = .systemGray6
        
        // Page Container
        pageContainerView.backgroundColor = .white
        pageContainerView.layer.shadowOpacity = 0.15
        pageContainerView.layer.shadowRadius = 10
        pageContainerView.frame = CGRect(origin: .zero, size: PageData.virtualSize)
        view.addSubview(pageContainerView)
        
        // Background Image View
        backgroundImageView.translatesAutoresizingMaskIntoConstraints = false
        backgroundImageView.contentMode = .scaleToFill // Stretch to match page size exactly
        backgroundImageView.clipsToBounds = true
        pageContainerView.addSubview(backgroundImageView)
        
        NSLayoutConstraint.activate([
            backgroundImageView.topAnchor.constraint(equalTo: pageContainerView.topAnchor),
            backgroundImageView.leadingAnchor.constraint(equalTo: pageContainerView.leadingAnchor),
            backgroundImageView.trailingAnchor.constraint(equalTo: pageContainerView.trailingAnchor),
            backgroundImageView.bottomAnchor.constraint(equalTo: pageContainerView.bottomAnchor)
        ])
        
        // Body Text View (Standard Word-style)
        // Make it fill the entire page, but use insets for padding.
        bodyTextView.frame = pageContainerView.bounds
        bodyTextView.textContainerInset = UIEdgeInsets(top: 40, left: 40, bottom: 40, right: 40)
        bodyTextView.backgroundColor = .clear
        bodyTextView.font = .systemFont(ofSize: 18)
        bodyTextView.textColor = .black
        bodyTextView.delegate = self
        bodyTextView.isScrollEnabled = false 
        bodyTextView.isUserInteractionEnabled = true // Ensure interaction
        
        // Canvas Tap for Keyboard Dismissal
        let canvasTap = UITapGestureRecognizer(target: self, action: #selector(handleCanvasTap))
        canvasTap.delegate = self
        bodyTextView.addGestureRecognizer(canvasTap)
        
        pageContainerView.addSubview(bodyTextView)
        
        // Objects Layer (Images) - Above text
        // PassThroughView ensures touches only hit images, otherwise pass to text view.
        objectsLayer.frame = pageContainerView.bounds
        // objectsLayer.isUserInteractionEnabled = true // Default is true
        pageContainerView.addSubview(objectsLayer)
        
        // PencilKit (iPad Only) - Above everything
        if isiPad {
            canvasView.frame = pageContainerView.bounds
            canvasView.backgroundColor = .clear
            canvasView.delegate = self
            canvasView.drawingPolicy = .anyInput
            
            if let drawing = viewModel.restoreDrawing() {
                canvasView.drawing = drawing
            }
            pageContainerView.addSubview(canvasView)
        }
        
        if isEditable {
            setupToolbar()
            setupFormattingToolbar()
        }
    }
    
    private func setupFormattingToolbar() {
        editorToolbar.translatesAutoresizingMaskIntoConstraints = false
        editorToolbar.delegate = self
        view.addSubview(editorToolbar)
        
        NSLayoutConstraint.activate([
            editorToolbar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            editorToolbar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            editorToolbar.bottomAnchor.constraint(equalTo: view.bottomAnchor), // Pin to bottom (handles safe area internally)
        ])
    }
    
    private func deselectAllElements() {
        objectsLayer.subviews.forEach { view in
            if let element = view as? CanvasElementView {
                element.deselect()
            }
        }
    }
    
    private func setupToolbar() {
        var rightItems: [UIBarButtonItem] = []
        var leftItems: [UIBarButtonItem] = []
        
        if viewModel.recipient != nil {
            // Send Mode
            let sendBtn = UIBarButtonItem(title: "Invia", style: .done, target: self, action: #selector(sendAction))
            sendBtn.tintColor = .systemBlue
            rightItems.append(sendBtn)
        } else {
            // Edit/Save Mode
            let saveBtn = UIBarButtonItem(title: "Salva", style: .done, target: self, action: #selector(saveAction))
            rightItems.append(saveBtn)
        }
        
        if isiPad {
            let modeBtn = UIBarButtonItem(image: UIImage(systemName: "hand.draw"), style: .plain, target: self, action: #selector(toggleMode))
            rightItems.append(modeBtn)
        }
        
        let photoBtn = UIBarButtonItem(image: UIImage(systemName: "photo.on.rectangle"), style: .plain, target: self, action: #selector(openPhotoPicker))
        leftItems.append(photoBtn)
        
        // Back Button
        let backBtn = UIBarButtonItem(image: UIImage(systemName: "chevron.left"), style: .plain, target: self, action: #selector(handleBack))
        leftItems.insert(backBtn, at: 0) // Add to start
        
        navigationItem.rightBarButtonItems = rightItems
        navigationItem.leftBarButtonItems = leftItems
    }
    
    @objc private func sendAction() {
        guard let snapshotData = generateSnapshot() else {
            let alert = UIAlertController(title: "Errore", message: "Impossibile generare l'immagine della lettera.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
            return
        }
        
        // Show loading indicator
        let loadingAlert = UIAlertController(title: "Invio in corso...", message: nil, preferredStyle: .alert)
        let indicator = UIActivityIndicatorView(frame: CGRect(x: 10, y: 5, width: 50, height: 50))
        indicator.hidesWhenStopped = true
        indicator.startAnimating()
        loadingAlert.view.addSubview(indicator)
        present(loadingAlert, animated: true)
        
        Task {
            do {
                try await viewModel.sendLetter(imageData: snapshotData)
                dismiss(animated: true) { [weak self] in
                    self?.dismiss(animated: true) // Dismiss editor
                }
            } catch {
                dismiss(animated: true) { [weak self] in
                    let alert = UIAlertController(title: "Errore", message: error.localizedDescription, preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "OK", style: .default))
                    self?.present(alert, animated: true)
                }
            }
        }
    }
    
    private func generateSnapshot() -> Data? {
        let renderer = UIGraphicsImageRenderer(bounds: pageContainerView.bounds)
        let image = renderer.image { context in
            pageContainerView.drawHierarchy(in: pageContainerView.bounds, afterScreenUpdates: true)
        }
        return image.jpegData(compressionQuality: 0.8)
    }
    
    @objc private func handleBack() {
        dismiss(animated: true)
    }
    
    private func fitPageToScreen() {
        let targetSize = PageData.virtualSize
        let padding: CGFloat = 20
        let availableSize = CGSize(
            width: view.bounds.width - (padding * 2),
            height: view.bounds.height - (padding * 2) - view.safeAreaInsets.top - view.safeAreaInsets.bottom
        )
        let scale = min(availableSize.width / targetSize.width, availableSize.height / targetSize.height)
        pageContainerView.transform = CGAffineTransform(scaleX: scale, y: scale)
        pageContainerView.center = CGPoint(x: view.bounds.midX, y: view.bounds.midY)
    }
    
    private func setupBindings() {
        viewModel.onDataLoaded = { [weak self] in
            self?.refreshObjectsLayer()
        }
    }
    
    private func refreshObjectsLayer() {
        objectsLayer.subviews.forEach { $0.removeFromSuperview() }
        for item in viewModel.pageData.items {
            // Only show images in objects layer now, text is in bodyTextView
            if item.type == .image {
                let elementView = CanvasElementView(item: item)
                elementView.isUserInteractionEnabled = isEditable
                elementView.delegate = self
                objectsLayer.addSubview(elementView)
            }
        }
    }
    
    @objc private func toggleMode(_ sender: UIBarButtonItem) {
        guard isEditable, isiPad else { return }
        isDrawingMode.toggle()
        sender.image = UIImage(systemName: isDrawingMode ? "hand.draw" : "cursorarrow")
    }
    
    private func updateInputMode() {
        guard isEditable, isiPad else { return }
        canvasView.isUserInteractionEnabled = isDrawingMode
        toolPicker.setVisible(isDrawingMode, forFirstResponder: canvasView)
        if isDrawingMode { canvasView.becomeFirstResponder() } else { canvasView.resignFirstResponder() }
        bodyTextView.isUserInteractionEnabled = !isDrawingMode
    }
    
    @objc private func saveAction() {
        if isiPad {
            viewModel.saveDrawing(canvasView.drawing)
        } else {
            viewModel.saveDrawing(PKDrawing()) // Empty drawing for iPhone
        }
        let alert = UIAlertController(title: "Salvato", message: nil, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    @objc private func openPhotoPicker() {
        var config = PHPickerConfiguration()
        config.selectionLimit = 1
        config.filter = .images
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = self
        present(picker, animated: true)
    }
    
    func elementDidUpdate(id: UUID, newFrame: CGRect, newRotation: CGFloat) {
        viewModel.updateItem(id: id, frame: newFrame, rotation: newRotation)
    }
    
    func elementDidRequestTextEdit(_ element: CanvasElementView) {
        // Deprecated for floating text
    }
    
    func elementDidRequestDelete(_ element: CanvasElementView) {
        viewModel.removeItem(id: element.id)
    }
    
    // MARK: - UITextViewDelegate
    func textViewDidChange(_ textView: UITextView) {
        viewModel.updateBodyText(textView.text) // Keep plain text sync
        viewModel.updateAttributedBodyText(textView.attributedText)
    }
    
    func textViewDidChangeSelection(_ textView: UITextView) {
        // Ensure that if we just moved the cursor (length 0), we enforce our "pen" style
        if textView.selectedRange.length == 0 {
            var attributes = textView.typingAttributes
            attributes[.font] = currentFont
            attributes[.foregroundColor] = currentTextColor
            textView.typingAttributes = attributes
            
            // Also update slider to reflect current font size
            editorToolbar.updateSliderValue(Float(currentFont.pointSize))
        } else {
            // If text IS selected, update our internal state to match the selection
            if let font = textView.typingAttributes[.font] as? UIFont {
                currentFont = font
                editorToolbar.updateSliderValue(Float(font.pointSize))
            }
            if let color = textView.typingAttributes[.foregroundColor] as? UIColor {
                currentTextColor = color
            }
        }
    }
    
    private func updateTextAttributes(_ attributes: [NSAttributedString.Key: Any]) {
        // Update local state variables
        if let font = attributes[.font] as? UIFont {
            currentFont = font
        }
        if let color = attributes[.foregroundColor] as? UIColor {
            currentTextColor = color
        }
        
        // Apply to selection if exists
        if bodyTextView.selectedRange.length > 0 {
            bodyTextView.textStorage.addAttributes(attributes, range: bodyTextView.selectedRange)
        }
        
        // ALWAYS update typing attributes for future text
        var newAttributes = bodyTextView.typingAttributes
        newAttributes[.font] = currentFont
        newAttributes[.foregroundColor] = currentTextColor
        bodyTextView.typingAttributes = newAttributes
        
        viewModel.updateAttributedBodyText(bodyTextView.attributedText)
    }
    
    // MARK: - Gestures
    
    @objc private func handleCanvasTap() {
        view.endEditing(true)
    }
}

// MARK: - UIGestureRecognizerDelegate
extension MemoryEditorViewController: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        // Only handle our specific tap gesture on the text view
        if gestureRecognizer.view == bodyTextView {
            // If keyboard is NOT open, don't interfere (let it open)
            guard bodyTextView.isFirstResponder else { return false }
            
            let point = touch.location(in: bodyTextView)
            let layoutManager = bodyTextView.layoutManager
            let textContainer = bodyTextView.textContainer
            
            // Adjust point to text container coordinates
            var location = point
            location.x -= bodyTextView.textContainerInset.left
            location.y -= bodyTextView.textContainerInset.top
            
            // If text is empty, any tap is whitespace -> dismiss
            if bodyTextView.text.isEmpty {
                return true
            }
            
            // Find glyph index at this point
            let glyphIndex = layoutManager.glyphIndex(for: location, in: textContainer)
            
            // Check if the point is within the line fragment of the glyph
            var effectiveRange = NSRange(location: 0, length: 0)
            let lineRect = layoutManager.lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: &effectiveRange)
            
            if lineRect.contains(location) {
                return false // It's on a text line -> let text view handle it (move cursor)
            }
            
            return true // It's whitespace -> dismiss
        }
        return true
    }
}

// MARK: - EditorToolbarDelegate
extension MemoryEditorViewController: EditorToolbarDelegate {
    func didTapFont() {
        let config = UIFontPickerViewController.Configuration()
        config.includeFaces = true
        config.displayUsingSystemFont = false 
        config.filteredTraits = [] // Allow all fonts, even single-style ones
        let picker = UIFontPickerViewController(configuration: config)
        picker.selectedFontDescriptor = currentFont.fontDescriptor // Show checkmark on current font
        picker.delegate = self
        present(picker, animated: true)
    }
    
    func didTapTextColor() {
        let picker = UIColorPickerViewController()
        picker.selectedColor = currentTextColor
        picker.delegate = self
        activeColorPickerMode = .text
        present(picker, animated: true)
    }
    
    func didTapBackgroundColor() {
        let picker = BackgroundPickerViewController()
        picker.delegate = self
        if let sheet = picker.sheetPresentationController {
            sheet.detents = [.medium()]
        }
        present(picker, animated: true)
    }
    
    func didChangeTextSize(_ size: Float) {
        // Create new font with same descriptor but new size
        let newFont = currentFont.withSize(CGFloat(size))
        updateTextAttributes([.font: newFont])
    }
    
    func didTapKeyboardDismiss() {
        view.endEditing(true)
    }
}

// MARK: - BackgroundPickerDelegate
extension MemoryEditorViewController: BackgroundPickerDelegate {
    func didSelectBackgroundColor(_ color: UIColor) {
        pageContainerView.backgroundColor = color
        backgroundImageView.image = nil // Clear image if color selected
        viewModel.updateBackgroundColor(color)
        viewModel.updateBackgroundImageName(nil)
    }
    
    func didSelectBackgroundImage(_ imageName: String) {
        backgroundImageView.image = UIImage(named: imageName)
        pageContainerView.backgroundColor = .clear // Clear base color so only image shows
        viewModel.updateBackgroundImageName(imageName)
    }
}

// MARK: - UIFontPickerViewControllerDelegate
extension MemoryEditorViewController: UIFontPickerViewControllerDelegate {
    func fontPickerViewControllerDidPickFont(_ viewController: UIFontPickerViewController) {
        // Dismiss first to show the user the selection is accepted
        viewController.dismiss(animated: true)
        
        guard let descriptor = viewController.selectedFontDescriptor else { return }
        // Keep current size
        let newFont = UIFont(descriptor: descriptor, size: currentFont.pointSize)
        updateTextAttributes([.font: newFont])
    }
}

// MARK: - UIColorPickerViewControllerDelegate
extension MemoryEditorViewController: UIColorPickerViewControllerDelegate {
    func colorPickerViewControllerDidFinish(_ viewController: UIColorPickerViewController) {
        let color = viewController.selectedColor
        applyColor(color)
    }
    
    func colorPickerViewControllerDidSelectColor(_ viewController: UIColorPickerViewController) {
        applyColor(viewController.selectedColor)
    }
    
    private func applyColor(_ color: UIColor) {
        // Only handle text color here as background is handled by custom picker
        if activeColorPickerMode == .text {
            updateTextAttributes([.foregroundColor: color])
        }
    }
}

// MARK: - PHPickerViewControllerDelegate
extension MemoryEditorViewController: PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        guard let provider = results.first?.itemProvider,
               provider.canLoadObject(ofClass: UIImage.self) else { return }
        
        provider.loadObject(ofClass: UIImage.self) { [weak self] image, error in
            guard let self = self, let image = image as? UIImage else { return }
            
            DispatchQueue.global(qos: .userInitiated).async {
                guard let jpegData = image.jpegData(compressionQuality: 0.8) else { return }
                let imageSize = image.size
                
                DispatchQueue.main.async {
                    let center = CGPoint(x: PageData.virtualSize.width / 2, y: PageData.virtualSize.height / 2)
                    self.viewModel.addImage(imageData: jpegData, imageSize: imageSize, center: center)
                    
                    if self.isiPad, self.isDrawingMode, let btn = self.navigationItem.rightBarButtonItems?.last {
                        self.toggleMode(btn)
                    }
                }
            }
        }
    }
}
