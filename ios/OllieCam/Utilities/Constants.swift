import Foundation

enum Constants {
    enum SSE {
        static let initialReconnectDelay: TimeInterval = 1
        static let maxReconnectDelay: TimeInterval = 30
        static let reconnectMultiplier: Double = 2
        static let dedupWindow: TimeInterval = 2 // seconds
    }

    enum UserInterface {
        static let alertDismissDelay: TimeInterval = 4
        static let backgroundColor = "1a1a2e"
        static let maxActivityLogEntries: Int = 50
    }

    enum Keychain {
        static let service = "com.olliecam.server"
        static let passwordKey = "serverPassword"
        static let urlKey = "serverURL"
    }
}
