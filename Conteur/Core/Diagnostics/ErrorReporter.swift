import Foundation
import os.log

struct ErrorReporter: Sendable {
    static let logger = Logger(subsystem: "com.daffa.conteur", category: "errors")

    static func record(
        _ error: Error,
        file: StaticString = #fileID,
        line: UInt = #line,
        extra: [String: String]? = nil
    ) {
        let logged = LoggedError(
            timestamp: .now,
            code: (error as NSError).code,
            domain: (error as NSError).domain,
            message: error.localizedDescription,
            file: String(describing: file),
            line: line,
            extra: extra ?? [:]
        )

        logger.error("\(logged.identifier): \(logged.message) (\(logged.file):\(logged.line))")
    }
}

struct LoggedError: Identifiable, Sendable, Codable {
    let id: UUID
    let timestamp: Date
    let code: Int
    let domain: String
    let message: String
    let file: String
    let line: UInt
    let extra: [String: String]

    init(
        timestamp: Date,
        code: Int,
        domain: String,
        message: String,
        file: String,
        line: UInt,
        extra: [String: String]
    ) {
        self.id = UUID()
        self.timestamp = timestamp
        self.code = code
        self.domain = domain
        self.message = message
        self.file = file
        self.line = line
        self.extra = extra
    }

    var identifier: String {
        "\(domain).\(code)"
    }
}
