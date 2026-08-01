// AuthService.swift
// HaispaceRuntime — Services
//
// Service layer untuk autentikasi ke Haispace API.
// Fase 0: Implementasi stub/mock untuk development.
// Fase 3: Replace dengan implementasi HTTP nyata ke https://api.haispace.id
//
// Ref: docs/design/30_authentication.md
// Ref: docs/design/32_server_infrastructure.md

import Foundation

// MARK: - AuthService Protocol

protocol AuthServiceProtocol {
    func registerDevice(boothId: String, buildNumber: String) async throws
    func validateToken(_ token: String) async throws -> HaispaceUser
    func logout(token: String) async throws
}

// MARK: - AuthService

/// Singleton service untuk semua operasi autentikasi.
/// Gunakan `AuthService.shared` — jangan buat instance baru.
final class AuthService {

    static let shared: any AuthServiceProtocol = {
        #if DEBUG
        return MockAuthService()
        #else
        return LiveAuthService()
        #endif
    }()

    private init() {}
}

// MARK: - Live Auth Service (Production)

final class LiveAuthService: AuthServiceProtocol {

    init() {}

    func registerDevice(boothId: String, buildNumber: String) async throws {
        let payload = DeviceRegistrationRequest(boothId: boothId, buildNumber: buildNumber)
        
        do {
            let bodyData = try JSONEncoder().encode(payload)
            let response: DeviceRegistrationResponse = try await HSPCloudClient.shared.request(
                endpoint: "/devices",
                method: "POST",
                body: bodyData,
                requiresAuth: false
            )
            
            // Simpan API Key & Booth ID ke Keychain
            KeychainHelper.saveApiKey(response.apiKey)
            KeychainHelper.saveBoothId(response.boothId)
            
            HaispaceLogger.info("Device successfully registered. Booth ID: \(response.boothId)", category: "auth")
        } catch {
            HaispaceLogger.error(error)
            throw error
        }
    }

    func validateToken(_ token: String) async throws -> HaispaceUser {
        // Not used for booth (Booth API uses X-Api-Key per request, no session to validate here)
        return .mockOperator
    }

    func logout(token: String) async throws {
        // Fire and forget — tidak kritis jika gagal
        guard let url = URL(string: "\(baseURL)/auth/logout") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        _ = try? await session.data(for: request)
    }
}

// MARK: - Mock Auth Service (Development / Preview)

final class MockAuthService: AuthServiceProtocol {

    // Simulasi delay network
    private let simulatedDelay: Duration = .milliseconds(800)

    func registerDevice(boothId: String, buildNumber: String) async throws {
        try? await Task.sleep(for: simulatedDelay)

        // Validasi mock credentials
        if boothId == "B-MOCK-1" {
            let token = "mock-api-key-\(UUID().uuidString)"
            KeychainHelper.saveApiKey(token)
            KeychainHelper.saveBoothId("B-MOCK-1")
            return
        }

        // Gagal login
        throw HaispaceError.authenticationError(reason: "Invalid Access Code")
    }

    func validateToken(_ token: String) async throws -> HaispaceUser {
        try? await Task.sleep(for: simulatedDelay)

        guard !token.isEmpty else {
            throw HaispaceError.authTokenExpired
        }

        // Mock: token admin
        if token.contains("admin") {
            return .mockAdmin
        }
        // Mock: token operator
        return .mockOperator
    }

    func logout(token: String) async throws {
        // Mock: tidak melakukan apa-apa
        HaispaceLogger.debug("MockAuthService: logout dipanggil")
    }
}

// MARK: - Login Response Model

private struct LoginResponse: Codable {
    let token: String
    let user: HaispaceUser
}
