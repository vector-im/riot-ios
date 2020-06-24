// File created from FlowTemplate
// $ createRootCoordinator.sh KeyBackupSetup/SecureSetup SecureKeyBackupSetup
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

import Foundation

@objc protocol SecureKeyBackupSetupCoordinatorBridgePresenterDelegate {
    func secureKeyBackupSetupCoordinatorBridgePresenterDelegateDidComplete(_ coordinatorBridgePresenter: SecureKeyBackupSetupCoordinatorBridgePresenter)
    func secureKeyBackupSetupCoordinatorBridgePresenterDelegateDidCancel(_ coordinatorBridgePresenter: SecureKeyBackupSetupCoordinatorBridgePresenter)
}

/// SecureKeyBackupSetupCoordinatorBridgePresenter enables to start SecureKeyBackupSetupCoordinator from a view controller.
/// This bridge is used while waiting for global usage of coordinator pattern.
@objcMembers
final class SecureKeyBackupSetupCoordinatorBridgePresenter: NSObject {
    
    // MARK: - Properties
    
    // MARK: Private
    
    private let session: MXSession
    private var coordinator: SecureKeyBackupSetupCoordinator?
    
    // MARK: Public
    
    weak var delegate: SecureKeyBackupSetupCoordinatorBridgePresenterDelegate?
    
    // MARK: - Setup
    
    init(session: MXSession) {
        self.session = session
        super.init()
    }
    
    // MARK: - Public
    
    // NOTE: Default value feature is not compatible with Objective-C.
    // func present(from viewController: UIViewController, animated: Bool) {
    //     self.present(from: viewController, animated: animated)
    // }
    
    func present(from viewController: UIViewController, animated: Bool) {
        let secureKeyBackupSetupCoordinator = SecureKeyBackupSetupCoordinator(session: self.session)
        secureKeyBackupSetupCoordinator.delegate = self
        viewController.present(secureKeyBackupSetupCoordinator.toPresentable(), animated: animated, completion: nil)
        secureKeyBackupSetupCoordinator.start()
        
        self.coordinator = secureKeyBackupSetupCoordinator
    }
    
    func dismiss(animated: Bool, completion: (() -> Void)?) {
        guard let coordinator = self.coordinator else {
            return
        }
        coordinator.toPresentable().dismiss(animated: animated) {
            self.coordinator = nil

            if let completion = completion {
                completion()
            }
        }
    }
}

// MARK: - SecureKeyBackupSetupCoordinatorDelegate
extension SecureKeyBackupSetupCoordinatorBridgePresenter: SecureKeyBackupSetupCoordinatorDelegate {
    func secureKeyBackupSetupCoordinatorDidComplete(_ coordinator: SecureKeyBackupSetupCoordinatorType) {
        self.delegate?.secureKeyBackupSetupCoordinatorBridgePresenterDelegateDidComplete(self)
    }
    
    func secureKeyBackupSetupCoordinatorDidCancel(_ coordinator: SecureKeyBackupSetupCoordinatorType) {
        self.delegate?.secureKeyBackupSetupCoordinatorBridgePresenterDelegateDidCancel(self)
    }
}