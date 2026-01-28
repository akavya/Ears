//
//  HLSAuthResourceLoader.swift
//  Ears
//
//  Resource loader delegate for HLS authentication
//  Intercepts segment requests and adds authentication tokens
//

import AVFoundation
import Foundation

/// Handles authentication for HLS streaming by intercepting resource requests.
///
/// AVPlayer doesn't automatically pass authentication to HLS segment requests.
/// This delegate intercepts those requests and adds the auth token.
///
/// Usage:
/// 1. Create the loader with your auth token
/// 2. Register it with AVURLAsset using setResourceLoader(_:queue:)
/// 3. Use a custom URL scheme (e.g., "ears-hls://") instead of "https://"
final class HLSAuthResourceLoader: NSObject, AVAssetResourceLoaderDelegate {

    // MARK: - Properties

    /// Authentication token to add to requests
    private let authToken: String

    /// Base URL of the server
    private let baseURL: URL

    /// Custom URL scheme used to trigger this delegate
    private let customScheme = "ears-hls"

    /// URLSession for making authenticated requests
    private let session: URLSession

    /// Active loading requests
    private var activeRequests: [AVAssetResourceLoadingRequest: URLSessionDataTask] = [:]

    // MARK: - Initialization

    init(authToken: String, baseURL: URL) {
        self.authToken = authToken
        self.baseURL = baseURL

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.httpAdditionalHeaders = [
            "Authorization": "Bearer \(authToken)"
        ]
        self.session = URLSession(configuration: config)

        super.init()
    }

    // MARK: - Public Methods

    /// Convert a standard HTTPS URL to use the custom scheme
    func customSchemeURL(from url: URL) -> URL? {
        var components = URLComponents(url: url, resolvingAgainstBaseURL: true)
        components?.scheme = customScheme
        return components?.url
    }

    /// Convert a custom scheme URL back to HTTPS
    func httpsURL(from customURL: URL) -> URL? {
        var components = URLComponents(url: customURL, resolvingAgainstBaseURL: true)
        components?.scheme = baseURL.scheme ?? "https"
        return components?.url
    }

    // MARK: - AVAssetResourceLoaderDelegate

    func resourceLoader(
        _ resourceLoader: AVAssetResourceLoader,
        shouldWaitForLoadingOfRequestedResource loadingRequest: AVAssetResourceLoadingRequest
    ) -> Bool {
        guard let customURL = loadingRequest.request.url else {
            print("[HLSAuth] No URL in loading request")
            loadingRequest.finishLoading(with: NSError(
                domain: "HLSAuthResourceLoader",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "No URL in request"]
            ))
            return false
        }

        // Convert custom scheme back to HTTPS
        guard let httpsURL = httpsURL(from: customURL) else {
            print("[HLSAuth] Failed to convert URL: \(customURL)")
            loadingRequest.finishLoading(with: NSError(
                domain: "HLSAuthResourceLoader",
                code: -2,
                userInfo: [NSLocalizedDescriptionKey: "Invalid URL"]
            ))
            return false
        }

        print("[HLSAuth] Loading: \(httpsURL.lastPathComponent)")

        // Create authenticated request
        var request = URLRequest(url: httpsURL)
        request.httpMethod = loadingRequest.request.httpMethod ?? "GET"
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")

        // Copy any additional headers from the original request
        if let headers = loadingRequest.request.allHTTPHeaderFields {
            for (key, value) in headers where key != "Authorization" {
                request.setValue(value, forHTTPHeaderField: key)
            }
        }

        // Handle the request
        let task = session.dataTask(with: request) { [weak self, weak loadingRequest] data, response, error in
            guard let self = self, let loadingRequest = loadingRequest else { return }

            // Clean up task reference
            self.activeRequests.removeValue(forKey: loadingRequest)

            // Handle errors
            if let error = error {
                print("[HLSAuth] Request failed: \(error.localizedDescription)")
                loadingRequest.finishLoading(with: error)
                return
            }

            guard let response = response as? HTTPURLResponse else {
                print("[HLSAuth] Invalid response type")
                loadingRequest.finishLoading(with: NSError(
                    domain: "HLSAuthResourceLoader",
                    code: -3,
                    userInfo: [NSLocalizedDescriptionKey: "Invalid response"]
                ))
                return
            }

            // Check status code
            guard (200...299).contains(response.statusCode) else {
                print("[HLSAuth] HTTP error: \(response.statusCode)")
                loadingRequest.finishLoading(with: NSError(
                    domain: "HLSAuthResourceLoader",
                    code: response.statusCode,
                    userInfo: [
                        NSLocalizedDescriptionKey: "HTTP \(response.statusCode)",
                        NSURLErrorKey: httpsURL
                    ]
                ))
                return
            }

            // Fill in content information
            if let contentInfo = loadingRequest.contentInformationRequest {
                contentInfo.contentType = response.mimeType
                contentInfo.contentLength = response.expectedContentLength
                contentInfo.isByteRangeAccessSupported = true
            }

            // Provide the data
            if let data = data, let dataRequest = loadingRequest.dataRequest {
                dataRequest.respond(with: data)
            }

            // Finish loading
            loadingRequest.finishLoading()
            print("[HLSAuth] Successfully loaded: \(httpsURL.lastPathComponent)")
        }

        // Store the task and start it
        activeRequests[loadingRequest] = task
        task.resume()

        return true
    }

    func resourceLoader(
        _ resourceLoader: AVAssetResourceLoader,
        didCancel loadingRequest: AVAssetResourceLoadingRequest
    ) {
        // Cancel the associated task
        if let task = activeRequests[loadingRequest] {
            task.cancel()
            activeRequests.removeValue(forKey: loadingRequest)
            print("[HLSAuth] Request cancelled")
        }
    }

    // MARK: - Cleanup

    func cancelAllRequests() {
        for (_, task) in activeRequests {
            task.cancel()
        }
        activeRequests.removeAll()
    }

    deinit {
        cancelAllRequests()
    }
}
