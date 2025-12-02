import UIKit
import PencilKit
import PhotosUI

class MemoryEditorViewController: UIViewController, PKCanvasViewDelegate, CanvasElementDelegate {
    
    private let viewModel: EditorViewModel
    private var isEditable: Bool
    
    // UI Elements
    private let pageContainerView = UIView()
    private let objectsLayer = UIView()
    private let canvasView = PKCanvasView()
    private let toolPicker = PKToolPicker()
    
    private var isDrawingMode = true {
        didSet { updateInputMode() }
    }
    
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
        } else {
            updateInputMode()
        }
        
        viewModel.restoreDrawing()
        refreshObjectsLayer()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        fitPageToScreen()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if isEditable, let window = view.window {
            toolPicker.setVisible(true, forFirstResponder: canvasView)
            toolPicker.addObserver(canvasView)
            canvasView.becomeFirstResponder()
        }
    }
    
    private func setupUI() {
        view.backgroundColor = .systemGray6
        
        pageContainerView.backgroundColor = .white
        pageContainerView.layer.shadowOpacity = 0.15
        pageContainerView.layer.shadowRadius = 10
        pageContainerView.frame = CGRect(origin: .zero, size: PageData.virtualSize)
        view.addSubview(pageContainerView)
        
        objectsLayer.frame = pageContainerView.bounds
        pageContainerView.addSubview(objectsLayer)
        
        canvasView.frame = pageContainerView.bounds
        canvasView.backgroundColor = .clear
        canvasView.delegate = self
        canvasView.drawingPolicy = .anyInput
        
        if let drawing = viewModel.restoreDrawing() {
            canvasView.drawing = drawing
        }
        pageContainerView.addSubview(canvasView)
        
        if isEditable {
            setupToolbar()
        }
    }
    
    private func setupToolbar() {
        let modeBtn = UIBarButtonItem(image: UIImage(systemName: "hand.draw"), style: .plain, target: self, action: #selector(toggleMode))
        let photoBtn = UIBarButtonItem(image: UIImage(systemName: "photo.on.rectangle"), style: .plain, target: self, action: #selector(openPhotoPicker))
        let textBtn = UIBarButtonItem(image: UIImage(systemName: "text.cursor"), style: .plain, target: self, action: #selector(addTextAction))
        let saveBtn = UIBarButtonItem(title: "Salva", style: .done, target: self, action: #selector(saveAction))
        
        navigationItem.rightBarButtonItems = [saveBtn, modeBtn]
        navigationItem.leftBarButtonItems = [photoBtn, textBtn]
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
            let elementView = CanvasElementView(item: item)
            elementView.isUserInteractionEnabled = isEditable
            elementView.delegate = self
            objectsLayer.addSubview(elementView)
        }
    }
    
    @objc private func toggleMode(_ sender: UIBarButtonItem) {
        guard isEditable else { return }
        isDrawingMode.toggle()
        sender.image = UIImage(systemName: isDrawingMode ? "hand.draw" : "cursorarrow")
    }
    
    private func updateInputMode() {
        guard isEditable else { return }
        canvasView.isUserInteractionEnabled = isDrawingMode
        toolPicker.setVisible(isDrawingMode, forFirstResponder: canvasView)
        if isDrawingMode { canvasView.becomeFirstResponder() } else { canvasView.resignFirstResponder() }
    }
    
    @objc private func saveAction() {
        viewModel.saveDrawing(canvasView.drawing)
        let alert = UIAlertController(title: "Salvato", message: nil, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    @objc private func addTextAction() {
        let center = CGPoint(x: PageData.virtualSize.width / 2, y: PageData.virtualSize.height / 2)
        viewModel.addText("Tocca due volte per modificare", center: center)
        if isDrawingMode { toggleMode(navigationItem.rightBarButtonItems!.last!) }
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
        guard isEditable else { return }
        let alert = UIAlertController(title: "Modifica Testo", message: nil, preferredStyle: .alert)
        alert.addTextField()
        let save = UIAlertAction(title: "OK", style: .default) { [weak self] _ in
            if let text = alert.textFields?.first?.text, !text.isEmpty {
                element.updateText(text)
                self?.viewModel.updateTextContent(id: element.id, newText: text)
            }
        }
        alert.addAction(save)
        alert.addAction(UIAlertAction(title: "Annulla", style: .cancel))
        present(alert, animated: true)
    }
}

extension MemoryEditorViewController: PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        guard let provider = results.first?.itemProvider,
              provider.canLoadObject(ofClass: UIImage.self) else { return }
        provider.loadObject(ofClass: UIImage.self) { [weak self] image, error in
            guard let self = self, let image = image as? UIImage else { return }
            DispatchQueue.main.async {
                let center = CGPoint(x: PageData.virtualSize.width / 2, y: PageData.virtualSize.height / 2)
                self.viewModel.addImage(image, center: center)
                if self.isDrawingMode, let btn = self.navigationItem.rightBarButtonItems?.last {
                    self.toggleMode(btn)
                }
            }
        }
    }
}
