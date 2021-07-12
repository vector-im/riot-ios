// File created from ScreenTemplate
// $ createScreen.sh Modal/Show ServiceTermsModalScreen
/*
 Copyright 2019 New Vector Ltd
 
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

protocol ServiceTermsModalScreenCoordinatorDelegate: AnyObject {
    func serviceTermsModalScreenCoordinatorDidAccept(_ coordinator: ServiceTermsModalScreenCoordinatorType)
    func serviceTermsModalScreenCoordinator(_ coordinator: ServiceTermsModalScreenCoordinatorType, displayPolicy policy: MXLoginPolicyData)
    func serviceTermsModalScreenCoordinatorDidDecline(_ coordinator: ServiceTermsModalScreenCoordinatorType)
    func serviceTermsModalScreenCoordinatorDidCancel(_ coordinator: ServiceTermsModalScreenCoordinatorType)
}

/// `ServiceTermsModalScreenCoordinatorType` is a protocol describing a Coordinator that handle key backup setup passphrase navigation flow.
protocol ServiceTermsModalScreenCoordinatorType: Coordinator, Presentable {
    var delegate: ServiceTermsModalScreenCoordinatorDelegate? { get }
}
