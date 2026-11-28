// SPDX-License-Identifier: AGPL-3.0-only
//
// Talks to the tenant's Vault Durable Object exactly the way a browser
// tab would — mirrors advocatra-mcp's cloud-client.ts. The session
// cookie is handled automatically by URLSession's own cookie storage
// (simpler than cloud-client.ts's manual cookie header — iOS gets this
// for free).
import Foundation

public struct CloudAuthError: Error, Sendable {
    public let message: String
}

public struct SnapshotDownload: Sendable {
    public let revision: Int
    public let snapshot: EncryptedEnvelope?
}

public struct SessionInfo: Sendable, Equatable {
    public let userId: String
    public let email: String
    public let tenantId: String
}

/// Just the one call VaultAccess-driven unlock needs — lets tests pass a fake instead of a real client.
public protocol ManifestSource: Sendable {
    func fetchManifest() async throws -> String?
}

/// Just the one call decrypting a snapshot needs — lets tests pass a fake instead of a real client.
public protocol SnapshotSource: Sendable {
    func fetchSnapshot() async throws -> SnapshotDownload
}

public final class AdvocatraCloudClient: ManifestSource, SnapshotSource, Sendable {
    private let tenantHost: String
    private let session: URLSession

    public init(tenantHost: String) {
        self.tenantHost = tenantHost
        let configuration = URLSessionConfiguration.default
        configuration.httpCookieStorage = HTTPCookieStorage()
        configuration.httpShouldSetCookies = true
        self.session = URLSession(configuration: configuration)
    }

    private func baseURL() throws -> URL {
        guard let url = URL(string: "https://\(tenantHost)") else {
            throw CloudAuthError(message: "\"\(tenantHost)\" is not a valid tenant host")
        }
        return url
    }

    public func login(email: String, password: String, totpCode: String?) async throws {
        var body: [String: String] = ["email": email, "password": password]
        if let totpCode, !totpCode.isEmpty {
            body["totpCode"] = totpCode
        }
        var request = URLRequest(url: try baseURL().appending(path: "/login"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw CloudAuthError(message: Self.errorMessage(from: data, fallback: "login failed"))
        }
    }

    public func fetchSession() async throws -> SessionInfo {
        let (data, response) = try await session.data(from: try baseURL().appending(path: "/session"))
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw CloudAuthError(message: "GET /session failed")
        }
        struct Body: Decodable {
            let userId: String
            let email: String
            let tenantId: String
        }
        let decoded = try JSONDecoder().decode(Body.self, from: data)
        return SessionInfo(userId: decoded.userId, email: decoded.email, tenantId: decoded.tenantId)
    }

    public func fetchManifest() async throws -> String? {
        let (data, response) = try await session.data(from: try baseURL().appending(path: "/vault/manifest"))
        guard let http = response as? HTTPURLResponse else {
            throw CloudAuthError(message: "no response from GET /vault/manifest")
        }
        if http.statusCode == 404 { return nil }
        guard (200...299).contains(http.statusCode) else {
            throw CloudAuthError(message: "GET /vault/manifest failed: \(http.statusCode)")
        }
        return String(data: data, encoding: .utf8)
    }

    public func putManifest(json: String) async throws {
        var request = URLRequest(url: try baseURL().appending(path: "/vault/manifest"))
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.httpBody = Data(json.utf8)
        let (_, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw CloudAuthError(message: "PUT /vault/manifest failed")
        }
    }

    public func fetchSnapshot() async throws -> SnapshotDownload {
        let (data, response) = try await session.data(from: try baseURL().appending(path: "/vault/snapshot"))
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw CloudAuthError(message: "GET /vault/snapshot failed")
        }
        struct Body: Decodable {
            let revision: Int
            let snapshot: EncryptedEnvelope?
        }
        let decoded = try JSONDecoder().decode(Body.self, from: data)
        return SnapshotDownload(revision: decoded.revision, snapshot: decoded.snapshot)
    }

    private static func errorMessage(from data: Data, fallback: String) -> String {
        struct ErrorBody: Decodable { let error: String? }
        guard let decoded = try? JSONDecoder().decode(ErrorBody.self, from: data), let message = decoded.error else {
            return fallback
        }
        return message
    }
}
