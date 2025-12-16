import UIKit

protocol BackgroundPickerDelegate: AnyObject {
    func didSelectBackgroundColor(_ color: UIColor)
    func didSelectBackgroundImage(_ imageName: String)
}

class BackgroundPickerViewController: UIViewController {
    
    weak var delegate: BackgroundPickerDelegate?
    
    private let colors: [UIColor] = [
        .white, .systemGray6, .systemGray5, .systemGray4, .systemGray3, .systemGray2, .systemGray, .black,
        .systemRed, .systemOrange, .systemYellow, .systemGreen, .systemMint, .systemTeal, .systemCyan, .systemBlue, .systemIndigo, .systemPurple, .systemPink, .systemBrown,
        UIColor(red: 1.0, green: 0.9, blue: 0.9, alpha: 1), // Pastel Red
        UIColor(red: 0.9, green: 1.0, blue: 0.9, alpha: 1), // Pastel Green
        UIColor(red: 0.9, green: 0.9, blue: 1.0, alpha: 1), // Pastel Blue
        UIColor(red: 1.0, green: 1.0, blue: 0.8, alpha: 1), // Pastel Yellow
        UIColor(red: 0.95, green: 0.9, blue: 0.8, alpha: 1) // Paper-ish
    ]
    
    private let templates: [String] = ["letterbg1"] // Add more as they become available
    
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        
        // Title
        let titleLabel = UILabel()
        titleLabel.text = "Background"
        titleLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(titleLabel)
        
        // Scroll View
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        contentView.translatesAutoresizingMaskIntoConstraints = false
        
        // Colors Section
        let colorsLabel = UILabel()
        colorsLabel.text = "Colors"
        colorsLabel.font = .systemFont(ofSize: 15, weight: .medium)
        colorsLabel.textColor = .secondaryLabel
        colorsLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(colorsLabel)
        
        let colorsGrid = createColorsGrid()
        colorsGrid.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(colorsGrid)
        
        // Templates Section
        let templatesLabel = UILabel()
        templatesLabel.text = "Templates"
        templatesLabel.font = .systemFont(ofSize: 15, weight: .medium)
        templatesLabel.textColor = .secondaryLabel
        templatesLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(templatesLabel)
        
        let templatesScroll = createTemplatesScroll()
        templatesScroll.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(templatesScroll)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 16),
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            scrollView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            
            colorsLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 0),
            colorsLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            
            colorsGrid.topAnchor.constraint(equalTo: colorsLabel.bottomAnchor, constant: 12),
            colorsGrid.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            colorsGrid.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            templatesLabel.topAnchor.constraint(equalTo: colorsGrid.bottomAnchor, constant: 30),
            templatesLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            
            templatesScroll.topAnchor.constraint(equalTo: templatesLabel.bottomAnchor, constant: 12),
            templatesScroll.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            templatesScroll.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            templatesScroll.heightAnchor.constraint(equalToConstant: 120),
            templatesScroll.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -40)
        ])
    }
    
    private func createColorsGrid() -> UIView {
        let container = UIView()
        let itemSize: CGFloat = 40
        let spacing: CGFloat = 12
        let columns = 6
        
        var currentRow: UIStackView?
        let mainStack = UIStackView()
        mainStack.axis = .vertical
        mainStack.spacing = spacing
        mainStack.alignment = .leading
        
        for (index, color) in colors.enumerated() {
            if index % columns == 0 {
                currentRow = UIStackView()
                currentRow?.axis = .horizontal
                currentRow?.spacing = spacing
                mainStack.addArrangedSubview(currentRow!)
            }
            
            let btn = UIButton(type: .custom)
            btn.backgroundColor = color
            btn.layer.cornerRadius = itemSize / 2
            btn.layer.borderWidth = 1
            btn.layer.borderColor = UIColor.systemGray5.cgColor
            btn.translatesAutoresizingMaskIntoConstraints = false
            btn.widthAnchor.constraint(equalToConstant: itemSize).isActive = true
            btn.heightAnchor.constraint(equalToConstant: itemSize).isActive = true
            
            // Action
            btn.addAction(UIAction { [weak self] _ in
                self?.delegate?.didSelectBackgroundColor(color)
            }, for: .touchUpInside)
            
            currentRow?.addArrangedSubview(btn)
        }
        
        container.addSubview(mainStack)
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            mainStack.topAnchor.constraint(equalTo: container.topAnchor),
            mainStack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            mainStack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            mainStack.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        
        return container
    }
    
    private func createTemplatesScroll() -> UIView {
        let scroll = UIScrollView()
        scroll.showsHorizontalScrollIndicator = false
        scroll.contentInset = UIEdgeInsets(top: 0, left: 20, bottom: 0, right: 20)
        
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(stack)
        
        for name in templates {
            let container = UIButton(type: .custom)
            container.translatesAutoresizingMaskIntoConstraints = false
            container.widthAnchor.constraint(equalToConstant: 80).isActive = true
            container.heightAnchor.constraint(equalToConstant: 100).isActive = true
            container.layer.cornerRadius = 8
            container.clipsToBounds = true
            container.layer.borderWidth = 1
            container.layer.borderColor = UIColor.systemGray4.cgColor
            
            if let image = UIImage(named: name) {
                container.setImage(image, for: .normal)
                container.imageView?.contentMode = .scaleAspectFill
            } else {
                // Fallback if asset missing
                container.backgroundColor = .systemGray6
                container.setTitle(name, for: .normal)
                container.setTitleColor(.black, for: .normal)
                container.titleLabel?.font = .systemFont(ofSize: 10)
            }
            
            container.addAction(UIAction { [weak self] _ in
                self?.delegate?.didSelectBackgroundImage(name)
            }, for: .touchUpInside)
            
            stack.addArrangedSubview(container)
        }
        
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: scroll.topAnchor),
            stack.leadingAnchor.constraint(equalTo: scroll.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: scroll.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: scroll.bottomAnchor),
            stack.heightAnchor.constraint(equalTo: scroll.heightAnchor)
        ])
        
        return scroll
    }
}
