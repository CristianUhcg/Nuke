import Foundation

// MARK: - Manager

@available(*, deprecated, message: "Renamed to `ImageTarget")
public typealias Target = ImageTarget

@available(*, deprecated, message: "Please use Nuke `Nuke.loadImage(with:into:)` functions instead. To load images w/o targets please use `ImagePipeline` directly.")
public final class Manager: Loading {
    public let loader: Loading
    public let cache: Caching?

    public static let shared = Manager(loader: Loader.shared, cache: Cache.shared)

    public init(loader: Loading, cache: Caching? = nil) {
        self.loader = loader; self.cache = cache
    }

    public func loadImage(with request: Request, into target: Target) {
        loadImage(with: request, into: target) { [weak target] in
            target?.handle(response: $0, isFromMemoryCache: $1)
        }
    }

    public typealias Handler = (Result<Image>, _ isFromMemoryCache: Bool) -> Void

    public func loadImage(with request: Request, into target: AnyObject, handler: @escaping Handler) {
        assert(Thread.isMainThread)

        let context = getContext(for: target)
        context.cts?.cancel()
        context.cts = nil

        if let image = cachedImage(for: request) {
            handler(.success(image), true)
            return
        }

        let cts = CancellationTokenSource()
        context.cts = cts

        _loadImage(with: request, token: cts.token) { [weak context] in
            guard let context = context, context.cts === cts else { return }
            handler($0, false)
            context.cts = nil
        }
    }

    public func cancelRequest(for target: AnyObject) {
        assert(Thread.isMainThread)
        let context = getContext(for: target)
        context.cts?.cancel()
        context.cts = nil
    }

    public func loadImage(with request: Request, token: CancellationToken?, completion: @escaping (Result<Image>) -> Void) {
        if let image = cachedImage(for: request) {
            DispatchQueue.main.async { completion(.success(image)) }
        } else {
            _loadImage(with: request, token: token, completion: completion)
        }
    }

    private func _loadImage(with request: Request, token: CancellationToken? = nil, completion: @escaping (Result<Image>) -> Void) {
        loader.loadImage(with: request, token: token) { [weak self] result in
            if let image = result.value {
                self?.store(image: image, for: request)
            }
            DispatchQueue.main.async { completion(result) }
        }
    }

    private func cachedImage(for request: Request) -> Image? {
        guard request.memoryCacheOptions.readAllowed else { return nil }
        return cache?[request]
    }

    private func store(image: Image, for request: Request) {
        guard request.memoryCacheOptions.writeAllowed else { return }
        cache?[request] = image
    }

    private static var contextAK = "Manager.Context.AssociatedKey"

    private func getContext(for target: AnyObject) -> Context {
        if let ctx = objc_getAssociatedObject(target, &Manager.contextAK) as? Context {
            return ctx
        }
        let ctx = Context()
        objc_setAssociatedObject(target, &Manager.contextAK, ctx, .OBJC_ASSOCIATION_RETAIN)
        return ctx
    }

    private final class Context {
        var cts: CancellationTokenSource?
        deinit { cts?.cancel() }
    }

    public func loadImage(with url: URL, into target: Target) {
        loadImage(with: Request(url: url), into: target)
    }

    public func loadImage(with url: URL, into target: AnyObject, handler: @escaping Handler) {
        loadImage(with: Request(url: url), into: target, handler: handler)
    }
}

// MARK: - Loading

@available(*, deprecated, message: "Please use ImagePipeline class directly. There is no direct alternative to `Loading` protocol in Nuke 7.")
public protocol Loading {
    func loadImage(with request: ImageRequest, token: CancellationToken?, completion: @escaping (Result<Image>) -> Void)
}

@available(*, deprecated, message: "Please use ImagePipeline class directly. There is no direct alternative to `Loading` protocol in Nuke 7.")
public extension Loading {
    public func loadImage(with request: ImageRequest, completion: @escaping (Result<Image>) -> Void) {
        self.loadImage(with: request, token: nil, completion: completion)
    }

    public func loadImage(with url: URL, token: CancellationToken? = nil, completion: @escaping (Result<Image>) -> Void) {
        self.loadImage(with: ImageRequest(url: url), token: token, completion: completion)
    }
}

@available(*, deprecated, message: "Please use `ImagePipeline` instead")
public final class Loader: Loading {

    public static let shared: Loading = Loader(loader: DataLoader())

    public struct Options {
        public var maxConcurrentDataLoadingTaskCount: Int = 6
        public var maxConcurrentImageProcessingTaskCount: Int = 2
        public var isDeduplicationEnabled = true
        public var isRateLimiterEnabled = true
        public var processor: (Image, ImageRequest) -> AnyImageProcessor? = { $1.processor }

        public init() {}
    }

    fileprivate let pipeline: ImagePipeline

    public init(loader: DataLoading, decoder: DataDecoding = DataDecoder(), options: Options = Options()) {
        self.pipeline = ImagePipeline {
            $0.dataLoader = loader
            $0.dataDecoder = decoder
            $0.imageCache = nil
            $0.maxConcurrentDataLoadingTaskCount = options.maxConcurrentDataLoadingTaskCount
            $0.maxConcurrentImageProcessingTaskCount = options.maxConcurrentImageProcessingTaskCount
            $0.isDeduplicationEnabled = options.isDeduplicationEnabled
            $0.isRateLimiterEnabled = options.isRateLimiterEnabled
            $0.processor = options.processor
        }
    }

    public func loadImage(with request: ImageRequest, token: CancellationToken?, completion: @escaping (Result<Image>) -> Void) {
        let task = pipeline.loadImage(with: request, completion: completion)
        token?.register { task.cancel() }
    }

    public typealias Error = ImagePipeline.Error
}

// MARK: - ImageRequest

public extension ImageRequest {
    @available(*, deprecated, message: "Please use `ImageTask` delegate instead. Settings this property will have no effect.`")
    public var progress: ProgressHandler? {
        get { return nil }
        set { }
    }
}

// MARK: - Renaming

@available(*, deprecated, message: "Please use `ImageRequest` instead")
public typealias Request = ImageRequest

@available(*, deprecated, message: "Please use `ImageCache` instead")
public typealias Cache = ImageCache

@available(*, deprecated, message: "Please use `ImageCaching` instead")
public typealias Caching = ImageCaching

@available(*, deprecated, message: "Please use `ImageProcessing` instead")
public typealias Processing = ImageProcessing

@available(*, deprecated, message: "Please use `ImageProcessorComposition` instead")
public typealias ProcessorComposition = ImageProcessorComposition

@available(*, deprecated, message: "Please use `AnyImageProcessor` instead")
public typealias AnyProcessor = AnyImageProcessor

#if !os(macOS)
@available(*, deprecated, message: "Please use `ImageDecompressor` instead")
public typealias Decompressor = ImageDecompressor
#endif

@available(*, deprecated, message: "Please use `ImagePreheater` instead")
public typealias Preheater = ImagePreheater

// MARK: - Deprecated ImagePipeline.Configuration Options

public extension ImagePipeline.Configuration {
/// The maximum number of concurrent data loading tasks. `6` by default.
    @available(*, deprecated, message: "Please set `maxConcurrentOperationCount` directly on `dataLoadingQueue`")
    public var maxConcurrentDataLoadingTaskCount: Int {
        get { return dataLoadingQueue.maxConcurrentOperationCount }
        set { dataLoadingQueue.maxConcurrentOperationCount = newValue }
    }

    /// The maximum number of concurrent image processing tasks. `2` by default.
    ///
    /// Parallelizing image processing might result in a performance boost
    /// in a certain scenarios, however it's not going to be noticable in most
    /// cases. Might increase memory usage.
    @available(*, deprecated, message: "Please set `maxConcurrentOperationCount` directly on `imageProcessingQueue`")
    public var maxConcurrentImageProcessingTaskCount: Int {
        get { return imageProcessingQueue.maxConcurrentOperationCount }
        set { imageProcessingQueue.maxConcurrentOperationCount = newValue }
    }

    @available(*, deprecated, message: "Please set `imageProcessor` instead`")
    public var processor: (Image, ImageRequest) -> AnyImageProcessor? {
        get { return imageProcessor }
        set { imageProcessor = newValue }
    }
}
