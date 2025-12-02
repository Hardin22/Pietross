import UIKit
import AuthenticationServices

class LoginViewController: UIViewController {
    
    // Callback per comunicare con SwiftUI
    var onLoginSuccessExternal: (() -> Void)?
    
    private let viewModel = LoginViewModel()
    
    // UI
    private let titleLabel: UILabel = {
        let l = UILabel()
        l.text = "Memories"
        l.font = .systemFont(ofSize: 40, weight: .bold)
        l.textAlignment = .center
        return l
    }()
    
    private let appleButton = ASAuthorizationAppleIDButton(type: .signIn, style: .black)
    private let activityIndicator = UIActivityIndicatorView(style: .medium)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        setupUI()
        setupBindings()
    }
    
    private func setupUI() {
        let stack = UIStackView(arrangedSubviews: [titleLabel, appleButton, activityIndicator])
        stack.axis = .vertical
        stack.spacing = 20
        stack.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(stack)
        
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),
            appleButton.heightAnchor.constraint(equalToConstant: 50)
        ])
        
        appleButton.addTarget(self, action: #selector(handleAppleLogin), for: .touchUpInside)
    }
    
    private func setupBindings() {
        viewModel.onLoginSuccess = { [weak self] in
            // Notifica SwiftUI che abbiamo finito
            self?.onLoginSuccessExternal?()
        }
    }
    
    @objc private func handleAppleLogin() {
        activityIndicator.startAnimating()
        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        viewModel.configureRequest(request: request)
        
        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        controller.performRequests()
    }
}

extension LoginViewController: ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        return self.view.window!
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        viewModel.handleAuthorization(authorization)
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        activityIndicator.stopAnimating()
        viewModel.handleError(error)
    }
}
