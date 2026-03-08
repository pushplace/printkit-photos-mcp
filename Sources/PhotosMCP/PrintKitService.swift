import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

final class PrintKitService: @unchecked Sendable {

    private let baseURL = "https://printkit.dev"

    // MARK: - Browse Products

    func listProducts() async throws -> String {
        let url = URL(string: "\(baseURL)/products.json")!
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw PrintKitError.requestFailed("Failed to fetch product catalog")
        }
        return String(data: data, encoding: .utf8) ?? "[]"
    }

    func getProduct(handle: String) async throws -> String {
        let url = URL(string: "\(baseURL)/products/\(handle).json")!
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw PrintKitError.requestFailed("Product not found: \(handle)")
        }
        return String(data: data, encoding: .utf8) ?? "{}"
    }

    // MARK: - Upload Photo

    /// Upload a local file to PrintKit. Returns (publicUrl, uploadedFilename).
    func uploadPhoto(filePath: String) async throws -> (publicUrl: String, filename: String) {
        let fileURL = URL(fileURLWithPath: filePath)
        let filename = fileURL.lastPathComponent

        // Detect content type
        let ext = fileURL.pathExtension.lowercased()
        let contentTypes: [String: String] = [
            "jpg": "image/jpeg", "jpeg": "image/jpeg",
            "png": "image/png", "webp": "image/webp",
            "heic": "image/heic",
        ]
        let contentType = contentTypes[ext] ?? "image/jpeg"

        // Step 1: Get presigned URL
        let presignURL = URL(string: "\(baseURL)/api/upload")!
        var presignRequest = URLRequest(url: presignURL)
        presignRequest.httpMethod = "POST"
        presignRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let presignBody: [String: String] = [
            "contentType": contentType,
            "filename": filename,
            "source": "photos-mcp",
        ]
        presignRequest.httpBody = try JSONSerialization.data(withJSONObject: presignBody)

        let (presignData, presignResponse) = try await URLSession.shared.data(for: presignRequest)
        guard let presignHttp = presignResponse as? HTTPURLResponse, presignHttp.statusCode == 200 else {
            throw PrintKitError.requestFailed("Upload presign failed")
        }

        guard let presignJSON = try JSONSerialization.jsonObject(with: presignData) as? [String: Any],
              let uploadUrlString = presignJSON["uploadUrl"] as? String,
              let publicUrl = presignJSON["publicUrl"] as? String,
              let uploadUrl = URL(string: uploadUrlString) else {
            throw PrintKitError.requestFailed("Invalid presign response")
        }

        // Step 2: PUT file to S3
        let fileData = try Data(contentsOf: fileURL)
        var putRequest = URLRequest(url: uploadUrl)
        putRequest.httpMethod = "PUT"
        putRequest.setValue(contentType, forHTTPHeaderField: "Content-Type")
        putRequest.httpBody = fileData

        let (_, putResponse) = try await URLSession.shared.data(for: putRequest)
        guard let putHttp = putResponse as? HTTPURLResponse, (200...299).contains(putHttp.statusCode) else {
            throw PrintKitError.requestFailed("S3 upload failed")
        }

        return (publicUrl: publicUrl, filename: filename)
    }

    // MARK: - Create Order

    /// Create an order and return the checkout URL.
    func createOrder(sku: String, photoUrls: [String]) async throws -> String {
        let orderURL = URL(string: "\(baseURL)/api/add-to-cart")!
        var request = URLRequest(url: orderURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "sku": sku,
            "source": "photos-mcp",
            "projectData": ["photos": photoUrls],
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let errText = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw PrintKitError.requestFailed("Order creation failed: \(errText)")
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let success = json["success"] as? Bool, success,
              let redirectUrl = json["redirectUrl"] as? String else {
            let errText = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw PrintKitError.requestFailed("Order failed: \(errText)")
        }

        return redirectUrl
    }
}

// MARK: - Errors

enum PrintKitError: Error, LocalizedError {
    case requestFailed(String)

    var errorDescription: String? {
        switch self {
        case .requestFailed(let msg):
            return msg
        }
    }
}
