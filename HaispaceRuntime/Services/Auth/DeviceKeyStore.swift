import Foundation

public protocol DeviceKeyStoreProtocol {
    func getDeviceToken() -> String?
    func saveDeviceToken(_ token: String)
    func clearToken()
}

public class DeviceKeyStore: DeviceKeyStoreProtocol {
    private let tokenKey = "id.haispaceproject.runtime.device_jwt"
    
    public init() {}
    
    public func getDeviceToken() -> String? {
        // Untuk kemudahan testing E.8, kita hardcode token development sementara jika belum ada,
        // atau Anda bisa mengubah baris ini saat produksi.
        if let stored = UserDefaults.standard.string(forKey: tokenKey) {
            return stored
        }
        
        // HACK: Development fallback
        // return "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
        return nil
    }
    
    public func saveDeviceToken(_ token: String) {
        UserDefaults.standard.set(token, forKey: tokenKey)
    }
    
    public func clearToken() {
        UserDefaults.standard.removeObject(forKey: tokenKey)
    }
}
