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
        static let maxActivityLogEntries: Int = 50
    }

    enum Keychain {
        static let service = "com.olliecam.server"
        // Legacy keys (used for migration only)
        static let passwordKey = "serverPassword"
        static let urlKey = "serverURL"
        // Multi-server password prefix
        static let serverPasswordPrefix = "serverPassword-"
    }

    enum Storage {
        static let savedServersKey = "savedServers"
        static let activeServerIDKey = "activeServerID"
        static let didMigrateLegacyServerKey = "didMigrateLegacyServer"
    }

    enum Notifications {
        static let defaultNtfyServer = "https://ntfy.sh"
    }
}
