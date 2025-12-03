import UIKit

protocol EditorToolbarDelegate: AnyObject {
    func didTapFont()
    func didTapTextColor()
    func didTapBackgroundColor()
    func didChangeTextSize(_ size: Float)
    func didTapKeyboardDismiss()
}

class EditorToolbarView: UIView {
    
    weak var delegate: EditorToolbarDelegate?
    
    private let fontButton = UIButton(type: .system)
    private let textColorButton = UIButton(type: .system)
    private let bgColorButton = UIButton(type: .system)
    private let textSizeSlider = UISlider()
    private let dismissKeyboardButton = UIButton(type: .system)
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    private func setupUI() {
        backgroundColor = .systemBackground
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.1
        layer.shadowOffset = CGSize(width: 0, height: -2)
        layer.shadowRadius = 5
        
        // Buttons Configuration
        configureButton(fontButton, icon: "textformat", action: #selector(handleFontTap))
        configureButton(textColorButton, icon: "paintbrush.fill", action: #selector(handleTextColorTap)) // Paintbrush for text
        configureButton(bgColorButton, icon: "square.fill", action: #selector(handleBgColorTap)) // Square for background
        configureButton(dismissKeyboardButton, icon: "keyboard.chevron.compact.down", action: #selector(handleDismissKeyboard))
        
        // Slider Configuration
        textSizeSlider.minimumValue = 12
        textSizeSlider.maximumValue = 48
        textSizeSlider.value = 18
        textSizeSlider.addTarget(self, action: #selector(handleSliderChange), for: .valueChanged)
        textSizeSlider.widthAnchor.constraint(equalToConstant: 120).isActive = true
        
        // Stack View
        let stack = UIStackView(arrangedSubviews: [fontButton, textColorButton, textSizeSlider, bgColorButton, dismissKeyboardButton])
        stack.axis = .horizontal
        stack.distribution = .equalSpacing
        stack.alignment = .center
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        
        addSubview(stack)
        
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            stack.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: -10)
        ])
    }
    
    private func configureButton(_ button: UIButton, icon: String, action: Selector) {
        let config = UIImage.SymbolConfiguration(pointSize: 20, weight: .medium)
        button.setImage(UIImage(systemName: icon, withConfiguration: config), for: .normal)
        button.tintColor = .label
        button.addTarget(self, action: action, for: .touchUpInside)
        // Add a larger touch target
        button.widthAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
        button.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
    }
    
    @objc private func handleFontTap() { delegate?.didTapFont() }
    @objc private func handleTextColorTap() { delegate?.didTapTextColor() }
    @objc private func handleBgColorTap() { delegate?.didTapBackgroundColor() }
    @objc private func handleSliderChange() { delegate?.didChangeTextSize(textSizeSlider.value) }
    @objc private func handleDismissKeyboard() { delegate?.didTapKeyboardDismiss() }
    
    // Helper to update slider value externally (e.g. when selecting text with different size)
    func updateSliderValue(_ value: Float) {
        textSizeSlider.setValue(value, animated: true)
    }
}
