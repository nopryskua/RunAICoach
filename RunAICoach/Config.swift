import Foundation

enum Config {
    enum Error: Swift.Error {
        case missingKey, invalidKey
    }

    static func value<T>(for key: String) throws -> T where T: LosslessStringConvertible {
        guard let object = Bundle.main.object(forInfoDictionaryKey: key) else {
            throw Error.missingKey
        }

        switch object {
        case let value as T:
            return value
        case let string as String:
            guard let value = T(string) else { fallthrough }
            return value
        default:
            throw Error.invalidKey
        }
    }
}

// MARK: - API Keys

extension Config {
    static var openAIApiKey: String {
        get throws {
            try value(for: "OPENAI_API_KEY")
        }
    }
}
