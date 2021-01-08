// 
// Copyright 2020 New Vector Ltd
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

import Foundation

class CallVCExitPipOperation: AsyncOperation {
    
    private var service: CallService
    private var callVC: CallViewController
    private var completion: (() -> Void)?
    
    init(service: CallService,
         callVC: CallViewController,
         completion: (() -> Void)? = nil) {
        self.service = service
        self.callVC = callVC
        self.completion = completion
    }
    
    override func main() {
        service.delegate?.callService(service, exitPipForCallViewController: callVC, completion: {
            self.finish()
            self.completion?()
        })
    }
    
}