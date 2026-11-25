// Adapted for Anyroom from Pylux, https://github.com/ForWard-Technologies-LLC/Pylux @ ca87a49, AGPL-3.0.
// SPDX-License-Identifier: LicenseRef-AGPL-3.0-only-OpenSSL
// Stream session state enum

import Foundation

enum StreamState: Equatable {
    case idle
    case connecting
    case connected
    case createError(errorCode: Int32, message: String?)
    case quit(reason: Int32, reasonString: String?)
    case loginPinRequest(pinIncorrect: Bool)
}

enum DisplayMode: String, CaseIterable {
    case fit = "Fit"
    case zoom = "Zoom"
    case stretch = "Stretch"
}
