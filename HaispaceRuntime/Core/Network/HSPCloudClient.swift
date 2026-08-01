import Foundation

/// HTTP Client terpusat untuk komunikasi dengan Haispace Cloud (NestJS Backend).
/// Secara otomatis menyuntikkan header Authorization/API Key dan Booth ID.
public final class HSPCloudClient {
    public static let shared = HSPCloudClient()
    
    // TODO: Gunakan Config dari AppState. Untuk pengujian lokal gunakan localhost.
    private let baseURL = "http://localhost:3000/v1"
    private let session: URLSession
    
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        self.session = URLSession(configuration: config)
    }
    
    /// Fungsi untuk melakukan request HTTP secara asinkron.
    public func request<T: Decodable>(
        endpoint: String,
        method: String = "GET",
        body: Data? = nil,
        requiresAuth: Bool = true
    ) async throws -> T {
        
        guard let url = URL(string: "\(baseURL)\(endpoint)") else {
            throw HaispaceError.apiResponseInvalid(endpoint: endpoint)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if requiresAuth {
            // Ambil dari KeychainHelper
            if let apiKey = KeychainHelper.getApiKey(),
               let boothId = KeychainHelper.getBoothId() {
                request.setValue(apiKey, forHTTPHeaderField: "X-Api-Key")
                request.setValue(boothId, forHTTPHeaderField: "X-Booth-Id")
            } else {
                throw HaispaceError.authTokenInvalid
            }
        }
        
        if let body = body {
            request.httpBody = body
        }
        
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw HaispaceError.networkUnavailable
        }
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw HaispaceError.apiResponseInvalid(endpoint: endpoint)
        }
        
        let decoder = JSONDecoder()
        // NestJS returns camelCase, ISO8601
        decoder.dateDecodingStrategy = .iso8601
        
        // Handle Error Response (4xx, 5xx)
        if !(200...299).contains(httpResponse.statusCode) {
            if let errorResponse = try? decoder.decode(CloudErrorResponse.self, from: data) {
                // Map Cloud error back to HaispaceError (or throw it directly)
                throw errorResponse.error
            }
            throw HaispaceError.apiResponseInvalid(endpoint: endpoint)
        }
        
        // Coba decode body jika T bukan tipe Void
        if T.self == EmptyResponse.self {
            return EmptyResponse() as! T
        }
        
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            print("HSPCloudClient Decoding Error: \(error)")
            throw HaispaceError.apiResponseInvalid(endpoint: endpoint)
        }
    }
}

/// Helper tipe kosong untuk endpoints yang mengembalikan 204 No Content atau kita abaikan response-nya.
public struct EmptyResponse: Decodable {}
