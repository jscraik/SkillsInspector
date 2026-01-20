import XCTest
@testable import SkillsCore

final class RemoteSkillClientTests: XCTestCase {
    override class func setUp() {
        URLProtocol.registerClass(MockURLProtocol.self)
    }

    override class func tearDown() {
        URLProtocol.unregisterClass(MockURLProtocol.self)
    }

    func testFetchLatestMapsFields() async throws {
        MockURLProtocol.requestHandler = { request in
            guard request.url?.path == "/api/v1/skills" else { throw URLError(.badURL) }
            let body = """
            { "items": [ { "slug": "demo", "displayName": "Demo Skill", "summary": "Sum", "updatedAt": 1700000000000, "latestVersion": { "version": "1.2.3", "createdAt": 1700000000000, "changelog": "" }, "stats": { "downloads": 10, "stars": 2 } } ] }
            """
            return (MockURLProtocol.makeResponse(for: request, statusCode: 200), body.data(using: .utf8)!)
        }
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)
        let client = RemoteSkillClient.live(baseURL: URL(string: "https://mock.local")!, session: session)
        let items = try await client.fetchLatest(5)
        XCTAssertEqual(items.count, 1)
        let item = items[0]
        XCTAssertEqual(item.slug, "demo")
        XCTAssertEqual(item.latestVersion, "1.2.3")
        XCTAssertEqual(item.downloads, 10)
        XCTAssertEqual(item.stars, 2)
    }

    func testSearchMapsOptionalFields() async throws {
        MockURLProtocol.requestHandler = { request in
            guard request.url?.path == "/api/v1/search" else { throw URLError(.badURL) }
            let body = """
            { "results": [ { "slug": "s1", "displayName": "Skill 1", "summary": null, "version": "0.1.0", "updatedAt": 1700000000000 } ] }
            """
            return (MockURLProtocol.makeResponse(for: request, statusCode: 200), body.data(using: .utf8)!)
        }
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)
        let client = RemoteSkillClient.live(baseURL: URL(string: "https://mock.local")!, session: session)
        let items = try await client.search("skill", 10)
        XCTAssertEqual(items.first?.slug, "s1")
        XCTAssertEqual(items.first?.latestVersion, "0.1.0")
    }

    func testFetchLatestVersion() async throws {
        MockURLProtocol.requestHandler = { request in
            guard request.url?.path == "/api/v1/skills/demo" else { throw URLError(.badURL) }
            let body = """
            { "latestVersion": { "version": "2.0.0", "createdAt": 1700000000000, "changelog": "" } }
            """
            return (MockURLProtocol.makeResponse(for: request, statusCode: 200), body.data(using: .utf8)!)
        }
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)
        let client = RemoteSkillClient.live(baseURL: URL(string: "https://mock.local")!, session: session)
        let version = try await client.fetchLatestVersion("demo")
        XCTAssertEqual(version, "2.0.0")
    }

    func testFetchManifestReturnsNilOn404() async throws {
        MockURLProtocol.requestHandler = { request in
            guard request.url?.path == "/api/v1/skills/demo/manifest" else { throw URLError(.badURL) }
            return (MockURLProtocol.makeResponse(for: request, statusCode: 404), Data())
        }
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)
        let client = RemoteSkillClient.live(baseURL: URL(string: "https://mock.local")!, session: session)
        let manifest = try await client.fetchManifest("demo", nil)
        XCTAssertNil(manifest)
    }
}

// MARK: - RemotePreviewCache Tests

final class RemotePreviewCacheTests: XCTestCase {
    var testCacheRoot: URL!

    override func setUp() async throws {
        testCacheRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("test-cache-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: testCacheRoot, withIntermediateDirectories: true)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: testCacheRoot)
    }

    func testCacheStoresAndLoadsPreview() {
        let cache = RemotePreviewCache(cacheRoot: testCacheRoot)
        let preview = RemoteSkillPreview(
            slug: "test-skill",
            version: "1.0.0",
            skillMarkdown: "# Test",
            changelog: "Initial release",
            signerKeyId: "key-123",
            manifest: nil,
            etag: "etag-123",
            fetchedAt: Date()
        )

        cache.store(preview)
        let loaded = cache.load(slug: "test-skill", version: "1.0.0", expectedManifestSHA256: nil, expectedETag: nil)

        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.slug, "test-skill")
        XCTAssertEqual(loaded?.version, "1.0.0")
        XCTAssertEqual(loaded?.skillMarkdown, "# Test")
    }

    func testCacheExpiresAfterTTL() {
        let shortTTL: TimeInterval = 0.1 // 100ms
        let cache = RemotePreviewCache(cacheRoot: testCacheRoot, ttl: shortTTL)
        let preview = RemoteSkillPreview(
            slug: "test-skill",
            version: "1.0.0",
            skillMarkdown: "# Test",
            changelog: nil,
            signerKeyId: nil,
            manifest: nil,
            etag: nil,
            fetchedAt: Date()
        )

        cache.store(preview)

        // Should load immediately
        var loaded = cache.load(slug: "test-skill", version: "1.0.0", expectedManifestSHA256: nil, expectedETag: nil)
        XCTAssertNotNil(loaded)

        // Wait for TTL to expire
        Thread.sleep(forTimeInterval: shortTTL + 0.1)

        // Should not load after TTL
        loaded = cache.load(slug: "test-skill", version: "1.0.0", expectedManifestSHA256: nil, expectedETag: nil)
        XCTAssertNil(loaded)
    }

    func testCacheValidatesAgainstETag() {
        let cache = RemotePreviewCache(cacheRoot: testCacheRoot)
        let preview = RemoteSkillPreview(
            slug: "test-skill",
            version: "1.0.0",
            skillMarkdown: "# Test",
            changelog: nil,
            signerKeyId: nil,
            manifest: nil,
            etag: "etag-123",
            fetchedAt: Date()
        )

        cache.store(preview)

        // Should load with matching ETag
        var loaded = cache.load(slug: "test-skill", version: "1.0.0", expectedManifestSHA256: nil, expectedETag: "etag-123")
        XCTAssertNotNil(loaded)

        // Should not load with mismatched ETag
        loaded = cache.load(slug: "test-skill", version: "1.0.0", expectedManifestSHA256: nil, expectedETag: "etag-different")
        XCTAssertNil(loaded)
    }

    func testCacheManifestExpiresAfterTTL() {
        let shortTTL: TimeInterval = 0.1
        let cache = RemotePreviewCache(cacheRoot: testCacheRoot, ttl: shortTTL)
        let manifest = RemoteArtifactManifest(
            name: "test",
            version: "1.0.0",
            sha256: "abc123",
            size: 1000,
            signature: nil,
            signerKeyId: nil,
            trustedSigners: nil,
            revokedKeys: nil,
            builtWith: nil,
            targets: nil,
            minAppVersion: nil
        )

        cache.storeManifest(slug: "test-skill", version: "1.0.0", manifest: manifest, etag: nil)

        // Should load immediately
        var loaded = cache.loadManifest(slug: "test-skill", version: "1.0.0")
        XCTAssertNotNil(loaded)

        // Wait for TTL to expire
        Thread.sleep(forTimeInterval: shortTTL + 0.1)

        // Should not load after TTL
        loaded = cache.loadManifest(slug: "test-skill", version: "1.0.0")
        XCTAssertNil(loaded)
    }

    func testCacheSizeLimitEvictsOldestEntries() {
        let smallSizeLimit: Int = 1024 // 1KB
        let cache = RemotePreviewCache(cacheRoot: testCacheRoot, ttl: 3600, maxCacheBytes: smallSizeLimit)

        // Create multiple previews that exceed the size limit
        for i in 0..<5 {
            let preview = RemoteSkillPreview(
                slug: "skill-\(i)",
                version: "1.0.0",
                skillMarkdown: String(repeating: "#", count: 500), // Large content
                changelog: String(repeating: "x", count: 500),
                signerKeyId: nil,
                manifest: nil,
                etag: nil,
                fetchedAt: Date().addingTimeInterval(-Double(i * 10)) // Stagger timestamps
            )
            cache.store(preview)
        }

        // Total cache size should be under the limit
        let totalSize = cache.totalCacheSize()
        XCTAssertLessThanOrEqual(totalSize, smallSizeLimit)
    }

    func testClearAllRemovesCacheEntries() {
        let cache = RemotePreviewCache(cacheRoot: testCacheRoot)
        let preview = RemoteSkillPreview(
            slug: "test-skill",
            version: "1.0.0",
            skillMarkdown: "# Test",
            changelog: nil,
            signerKeyId: nil,
            manifest: nil,
            etag: nil,
            fetchedAt: Date()
        )

        cache.store(preview)
        XCTAssertNotNil(cache.load(slug: "test-skill", version: "1.0.0", expectedManifestSHA256: nil, expectedETag: nil))

        cache.clearAll()

        XCTAssertNil(cache.load(slug: "test-skill", version: "1.0.0", expectedManifestSHA256: nil, expectedETag: nil))
    }

    func testTotalCacheSize() {
        let cache = RemotePreviewCache(cacheRoot: testCacheRoot)
        let preview = RemoteSkillPreview(
            slug: "test-skill",
            version: "1.0.0",
            skillMarkdown: "# Test",
            changelog: nil,
            signerKeyId: nil,
            manifest: nil,
            etag: nil,
            fetchedAt: Date()
        )

        XCTAssertEqual(cache.totalCacheSize(), 0)

        cache.store(preview)

        XCTAssertGreaterThan(cache.totalCacheSize(), 0)
    }
}

// MARK: - Mock URLProtocol

final class MockURLProtocol: URLProtocol {
    nonisolated(unsafe) static var requestHandler: (@Sendable (URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let handler = Self.requestHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.unsupportedURL))
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}

    static func makeResponse(for request: URLRequest, statusCode: Int = 200) -> HTTPURLResponse {
        HTTPURLResponse(url: request.url!, statusCode: statusCode, httpVersion: nil, headerFields: nil)!
    }
}
