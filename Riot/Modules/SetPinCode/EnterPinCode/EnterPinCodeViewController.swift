// File created from ScreenTemplate
// $ createScreen.sh SetPinCode/EnterPinCode EnterPinCode
/*
 Copyright 2020 New Vector Ltd
 
 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at
 
 http://www.apache.org/licenses/LICENSE-2.0
 
 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 */

import UIKit

final class EnterPinCodeViewController: UIViewController {
    
    // MARK: - Constants
    
    private enum Constants {
        static let aConstant: Int = 666
    }
    
    // MARK: - Properties
    
    // MARK: Outlets
    
    @IBOutlet private weak var logoImageView: UIImageView!
    @IBOutlet private weak var placeholderStackView: UIStackView!
    @IBOutlet private weak var digitsStackView: UIStackView!
    @IBOutlet private weak var informationLabel: UILabel!
    @IBOutlet private weak var forgotPinButton: UIButton!
    
    // MARK: Private

    private var viewModel: EnterPinCodeViewModelType!
    private var theme: Theme!
    private var keyboardAvoider: KeyboardAvoider?
    private var errorPresenter: MXKErrorPresentation!
    private var activityPresenter: ActivityIndicatorPresenter!

    // MARK: - Setup
    
    class func instantiate(with viewModel: EnterPinCodeViewModelType) -> EnterPinCodeViewController {
        let viewController = StoryboardScene.EnterPinCodeViewController.initialScene.instantiate()
        viewController.viewModel = viewModel
        viewController.theme = ThemeService.shared().theme
        return viewController
    }
    
    // MARK: - Life cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Do any additional setup after loading the view.
        
        self.setupViews()
//        self.keyboardAvoider = KeyboardAvoider(scrollViewContainerView: self.view, scrollView: self.scrollView)
        self.activityPresenter = ActivityIndicatorPresenter()
        self.errorPresenter = MXKErrorAlertPresentation()
        
        self.registerThemeServiceDidChangeThemeNotification()
        self.update(theme: self.theme)
        
        self.viewModel.viewDelegate = self
        
        if #available(iOS 13.0, *) {
            modalPresentationStyle = .fullScreen
            isModalInPresentation = true
        }

        self.viewModel.process(viewAction: .loadData)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        self.keyboardAvoider?.startAvoiding()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        self.keyboardAvoider?.stopAvoiding()
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return self.theme.statusBarStyle
    }
    
    // MARK: - Private
    
    private func update(theme: Theme) {
        self.theme = theme
        
        self.view.backgroundColor = theme.headerBackgroundColor
        
        if let navigationBar = self.navigationController?.navigationBar {
            theme.applyStyle(onNavigationBar: navigationBar)
        }

        // TODO: Set view colors here
        self.informationLabel.textColor = theme.textPrimaryColor

        updateThemesOfAllButtons(in: digitsStackView, with: theme)
    }
    
    private func updateThemesOfAllButtons(in view: UIView, with theme: Theme) {
        if let button = view as? UIButton {
            theme.applyStyle(onButton: button)
        } else {
            for subview in view.subviews {
                updateThemesOfAllButtons(in: subview, with: theme)
            }
        }
    }
    
    private func registerThemeServiceDidChangeThemeNotification() {
        NotificationCenter.default.addObserver(self, selector: #selector(themeDidChange), name: .themeServiceDidChangeTheme, object: nil)
    }
    
    @objc private func themeDidChange() {
        self.update(theme: ThemeService.shared().theme)
    }
    
    private func setupViews() {
        let cancelBarButtonItem = MXKBarButtonItem(title: VectorL10n.cancel, style: .plain) { [weak self] in
            self?.cancelButtonAction()
        }
        
        self.navigationItem.rightBarButtonItem = cancelBarButtonItem
        
        self.title = ""
    }

    private func render(viewState: EnterPinCodeViewState) {
        switch viewState {
        case .choosePin:
            self.renderChoosePin()
        case .confirmPin:
            self.renderConfirmPin()
        case .pinsDontMatch:
            self.renderPinsDontMatch()
        case .unlockByPin:
            self.renderUnlockByPin()
        case .wrongPin:
            self.renderWrongPin()
        case .wrongPinTooManyTimes:
            self.renderWrongPinTooManyTimes()
        case .forgotPin:
            self.renderForgotPin()
        case .confirmPinToDisable:
            self.renderConfirmPinToDisable()
        }
    }
    
    private func renderChoosePin() {
        self.logoImageView.isHidden = true
        self.informationLabel.text = VectorL10n.pinProtectionChoosePin
        self.forgotPinButton.isHidden = true
    }
    
    private func renderConfirmPin() {
        self.informationLabel.text = VectorL10n.pinProtectionConfirmPin
        
        //  reset placeholders
        renderPlaceholdersCount(0)
    }
    
    private func renderPinsDontMatch() {
        let error = NSError(domain: "", code: 0, userInfo: [
            NSLocalizedFailureReasonErrorKey: VectorL10n.pinProtectionMismatchErrorTitle,
            NSLocalizedDescriptionKey: VectorL10n.pinProtectionMismatchErrorMessage
        ])
        self.activityPresenter.removeCurrentActivityIndicator(animated: true)
        self.errorPresenter.presentError(from: self, forError: error, animated: true) {
            self.viewModel.process(viewAction: .pinsDontMatchAlertAction)
        }
    }
    
    private func renderUnlockByPin() {
        self.logoImageView.isHidden = false
        self.informationLabel.text = VectorL10n.pinProtectionEnterPin
        self.forgotPinButton.isHidden = false
    }
    
    private func renderWrongPin() {
        self.placeholderStackView.vc_shake()
    }
    
    private func renderWrongPinTooManyTimes() {
        let error = NSError(domain: "", code: 0, userInfo: [
            NSLocalizedFailureReasonErrorKey: VectorL10n.pinProtectionMismatchErrorTitle,
            NSLocalizedDescriptionKey: VectorL10n.pinProtectionMismatchErrorMessage
        ])
        self.activityPresenter.removeCurrentActivityIndicator(animated: true)
        self.errorPresenter.presentError(from: self, forError: error, animated: true) {
            
        }
    }
    
    private func renderForgotPin() {
        let controller = UIAlertController(title: VectorL10n.pinProtectionResetAlertTitle,
                                           message: VectorL10n.pinProtectionResetAlertMessage,
                                           preferredStyle: .alert)
        
        let resetAction = UIAlertAction(title: VectorL10n.pinProtectionResetAlertActionReset, style: .default) { (_) in
            self.viewModel.process(viewAction: .forgotPinAlertAction)
        }
        
        controller.addAction(resetAction)
        self.present(controller, animated: true, completion: nil)
    }
    
    private func renderConfirmPinToDisable() {
        self.logoImageView.isHidden = true
        self.informationLabel.text = VectorL10n.pinProtectionConfirmPinToDisable
        self.forgotPinButton.isHidden = true
    }
    
    private func renderPlaceholdersCount(_ count: Int) {
        UIView.animate(withDuration: 0.3) {
            for view in self.placeholderStackView.arrangedSubviews {
                guard let imageView = view as? UIImageView else { continue }
                if imageView.tag < count {
                    imageView.image = Asset.Images.placeholder.image
                } else {
                    imageView.image = Asset.Images.selectionUntick.image
                }
            }
        }
    }

    // MARK: - Actions

    @IBAction private func digitButtonAction(_ sender: UIButton) {
        self.viewModel.process(viewAction: .digitPressed(sender.tag))
    }
    
    @IBAction private func forgotPinButtonAction(_ sender: UIButton) {
        self.viewModel.process(viewAction: .forgotPinPressed)
    }

    private func cancelButtonAction() {
        self.viewModel.process(viewAction: .cancel)
    }
}


// MARK: - EnterPinCodeViewModelViewDelegate
extension EnterPinCodeViewController: EnterPinCodeViewModelViewDelegate {

    func enterPinCodeViewModel(_ viewModel: EnterPinCodeViewModelType, didUpdateViewState viewSate: EnterPinCodeViewState) {
        self.render(viewState: viewSate)
    }
    
    func enterPinCodeViewModel(_ viewModel: EnterPinCodeViewModelType, didUpdatePlaceholdersCount count: Int) {
        self.renderPlaceholdersCount(count)
    }
    
}