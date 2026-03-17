import Flutter
import Foundation
import Metal
import simd
import UIKit
import CoreVideo

@objc(FlutterPcdViewPlugin)
public final class FlutterPcdViewPlugin: NSObject, FlutterPlugin {
    private let messenger: FlutterBinaryMessenger
    private let textures: FlutterTextureRegistry
    private var channel: FlutterMethodChannel?
    private var rendererEntries: [Int64: NativeRendererEntry] = [:]

    private init(messenger: FlutterBinaryMessenger, textures: FlutterTextureRegistry) {
        self.messenger = messenger
        self.textures = textures
        super.init()
    }

    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = FlutterPcdViewPlugin(
            messenger: registrar.messenger(),
            textures: registrar.textures()
        )
        let channel = FlutterMethodChannel(
            name: "flutter_pcd_view/native_renderer",
            binaryMessenger: registrar.messenger()
        )
        instance.channel = channel
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "createRenderer":
            guard let args = call.arguments as? [String: Any] else {
                result(FlutterError(code: "invalid_args", message: "Expected map arguments", details: nil))
                return
            }

            do {
                let renderer = try IosPointCloudRenderer(textureRegistry: textures)
                renderer.updateConfig(
                    backgroundColor: Self.number(args["backgroundColor"])?.uint32Value ?? 0xFF000000,
                    pointSize: Self.number(args["pointSize"])?.floatValue ?? 2.0,
                    renderScale: Self.number(args["renderScale"])?.floatValue ?? 1.0
                )
                renderer.updateCamera(
                    rotationX: Self.number(args["rotationX"])?.floatValue ?? -0.3,
                    rotationY: Self.number(args["rotationY"])?.floatValue ?? 0.5,
                    zoom: Self.number(args["zoom"])?.floatValue ?? 1.0
                )

                let textureId = renderer.textureId
                let entry = NativeRendererEntry(
                    messenger: messenger,
                    textureId: textureId,
                    renderer: renderer,
                    onDispose: { [weak self] id in
                        self?.rendererEntries.removeValue(forKey: id)
                    }
                )
                rendererEntries[textureId] = entry
                result(textureId)
            } catch {
                result(
                    FlutterError(
                        code: "create_failed",
                        message: "Failed to create iOS Metal renderer",
                        details: error.localizedDescription
                    )
                )
            }
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private static func number(_ value: Any?) -> NSNumber? {
        value as? NSNumber
    }
}

private final class NativeRendererEntry: NSObject {
    private let channel: FlutterMethodChannel
    private let textureId: Int64
    fileprivate let renderer: IosPointCloudRenderer
    private let onDispose: (Int64) -> Void
    private var disposed = false

    init(
        messenger: FlutterBinaryMessenger,
        textureId: Int64,
        renderer: IosPointCloudRenderer,
        onDispose: @escaping (Int64) -> Void
    ) {
        self.textureId = textureId
        self.renderer = renderer
        self.onDispose = onDispose
        self.channel = FlutterMethodChannel(
            name: "flutter_pcd_view/native_renderer/\(textureId)",
            binaryMessenger: messenger
        )
        super.init()
        channel.setMethodCallHandler(handle)
    }

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard !disposed else {
            result(
                FlutterError(code: "disposed", message: "Renderer already disposed", details: nil)
            )
            return
        }

        guard let args = call.arguments as? [String: Any] else {
            if call.method == "dispose" {
                dispose()
                result(nil)
            } else {
                result(FlutterError(code: "invalid_args", message: "Expected map arguments", details: nil))
            }
            return
        }

        switch call.method {
        case "setViewport":
            let width = max(1, (args["width"] as? NSNumber)?.intValue ?? 1)
            let height = max(1, (args["height"] as? NSNumber)?.intValue ?? 1)
            renderer.setViewport(width: width, height: height)
            result(nil)
        case "updateConfig":
            renderer.updateConfig(
                backgroundColor: (args["backgroundColor"] as? NSNumber)?.uint32Value ?? 0xFF000000,
                pointSize: (args["pointSize"] as? NSNumber)?.floatValue ?? 2.0,
                renderScale: (args["renderScale"] as? NSNumber)?.floatValue ?? 1.0
            )
            result(nil)
        case "updateCamera":
            renderer.updateCamera(
                rotationX: (args["rotationX"] as? NSNumber)?.floatValue ?? -0.3,
                rotationY: (args["rotationY"] as? NSNumber)?.floatValue ?? 0.5,
                zoom: (args["zoom"] as? NSNumber)?.floatValue ?? 1.0
            )
            result(nil)
        case "loadPackedScene":
            let pointBytes = (args["points"] as? FlutterStandardTypedData)?.data ?? Data()
            let lineBytes = (args["lines"] as? FlutterStandardTypedData)?.data ?? Data()
            let pointCount = (args["pointCount"] as? NSNumber)?.intValue ?? 0
            let lineVertexCount = (args["lineVertexCount"] as? NSNumber)?.intValue ?? 0
            renderer.loadScene(
                pointBytes: pointBytes,
                pointCount: pointCount,
                lineBytes: lineBytes,
                lineVertexCount: lineVertexCount
            )
            result(nil)
        case "dispose":
            dispose()
            result(nil)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func dispose() {
        guard !disposed else { return }
        disposed = true
        channel.setMethodCallHandler(nil)
        renderer.dispose()
        onDispose(textureId)
    }
}

private final class IosPointCloudRenderer: NSObject, FlutterTexture {
    private let textureRegistry: FlutterTextureRegistry
    private let commandQueue: MTLCommandQueue
    private let device: MTLDevice
    private let metalQueue = DispatchQueue(label: "flutter_pcd_view.ios_renderer")
    private let lock = NSLock()

    private var textureIdValue: Int64 = 0
    private var textureCache: CVMetalTextureCache?
    private var pixelBuffer: CVPixelBuffer?
    private var colorTexture: CVMetalTexture?
    private var depthTexture: MTLTexture?

    private var viewportWidth: Int = 1
    private var viewportHeight: Int = 1
    private var pointSize: Float = 2.0
    private var renderScale: Float = 1.0
    private var backgroundColor: UInt32 = 0xFF000000
    private var rotationX: Float = -0.3
    private var rotationY: Float = 0.5
    private var zoom: Float = 1.0

    private var pointBuffer: MTLBuffer?
    private var pointCount: Int = 0
    private var lineBuffer: MTLBuffer?
    private var lineVertexCount: Int = 0

    private let pointPipeline: MTLRenderPipelineState
    private let linePipeline: MTLRenderPipelineState
    private let depthState: MTLDepthStencilState

    var textureId: Int64 { textureIdValue }

    init(textureRegistry: FlutterTextureRegistry) throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw RendererError(message: "Metal device unavailable")
        }
        guard let commandQueue = device.makeCommandQueue() else {
            throw RendererError(message: "Failed to create Metal command queue")
        }

        self.textureRegistry = textureRegistry
        self.device = device
        self.commandQueue = commandQueue

        let library = try device.makeLibrary(source: Self.shaderSource, options: nil)
        let pointVertexFunction = library.makeFunction(name: "point_vertex_main")
        let lineVertexFunction = library.makeFunction(name: "line_vertex_main")
        let pointFragment = library.makeFunction(name: "point_fragment")
        let lineFragment = library.makeFunction(name: "line_fragment")

        guard let pointVertexFunction,
              let lineVertexFunction,
              let pointFragment,
              let lineFragment else {
            throw RendererError(message: "Failed to create Metal shader functions")
        }

        let pointDescriptor = MTLRenderPipelineDescriptor()
        pointDescriptor.vertexFunction = pointVertexFunction
        pointDescriptor.fragmentFunction = pointFragment
        pointDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        pointDescriptor.depthAttachmentPixelFormat = .depth32Float
        pointDescriptor.inputPrimitiveTopology = .point
        pointDescriptor.vertexDescriptor = Self.vertexDescriptor

        let lineDescriptor = MTLRenderPipelineDescriptor()
        lineDescriptor.vertexFunction = lineVertexFunction
        lineDescriptor.fragmentFunction = lineFragment
        lineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        lineDescriptor.depthAttachmentPixelFormat = .depth32Float
        lineDescriptor.inputPrimitiveTopology = .line
        lineDescriptor.vertexDescriptor = Self.vertexDescriptor

        self.pointPipeline = try device.makeRenderPipelineState(descriptor: pointDescriptor)
        self.linePipeline = try device.makeRenderPipelineState(descriptor: lineDescriptor)

        let depthDescriptor = MTLDepthStencilDescriptor()
        depthDescriptor.depthCompareFunction = .lessEqual
        depthDescriptor.isDepthWriteEnabled = true
        guard let depthState = device.makeDepthStencilState(descriptor: depthDescriptor) else {
            throw RendererError(message: "Failed to create depth state")
        }
        self.depthState = depthState

        super.init()

        var cache: CVMetalTextureCache?
        let cacheStatus = CVMetalTextureCacheCreate(
            kCFAllocatorDefault,
            nil,
            device,
            nil,
            &cache
        )
        guard cacheStatus == kCVReturnSuccess, let cache else {
            throw RendererError(message: "Failed to create CVMetalTextureCache: \(cacheStatus)")
        }
        self.textureCache = cache

        textureIdValue = textureRegistry.register(self)
        metalQueue.async { [weak self] in
            self?.renderFrameIfPossible()
        }
    }

    func copyPixelBuffer() -> Unmanaged<CVPixelBuffer>? {
        lock.lock()
        defer { lock.unlock() }
        guard let pixelBuffer else { return nil }
        return Unmanaged.passRetained(pixelBuffer)
    }

    func setViewport(width: Int, height: Int) {
        metalQueue.async {
            self.viewportWidth = max(1, width)
            self.viewportHeight = max(1, height)
            self.recreateRenderTargets()
            self.renderFrameIfPossible()
        }
    }

    func updateConfig(backgroundColor: UInt32, pointSize: Float, renderScale: Float) {
        metalQueue.async {
            self.backgroundColor = backgroundColor
            self.pointSize = pointSize
            self.renderScale = min(max(renderScale, 0.5), 2.0)
            self.recreateRenderTargets()
            self.renderFrameIfPossible()
        }
    }

    func updateCamera(rotationX: Float, rotationY: Float, zoom: Float) {
        metalQueue.async {
            self.rotationX = rotationX
            self.rotationY = rotationY
            self.zoom = max(zoom, 0.05)
            self.renderFrameIfPossible()
        }
    }

    func loadScene(pointBytes: Data, pointCount: Int, lineBytes: Data, lineVertexCount: Int) {
        metalQueue.async {
            self.pointCount = pointCount
            self.lineVertexCount = lineVertexCount
            self.pointBuffer = self.makeBuffer(from: pointBytes)
            self.lineBuffer = self.makeBuffer(from: lineBytes)
            self.renderFrameIfPossible()
        }
    }

    func dispose() {
        let textureId = textureIdValue
        DispatchQueue.main.async {
            self.textureRegistry.unregisterTexture(textureId)
        }
        metalQueue.async {
            self.lock.lock()
            self.pixelBuffer = nil
            self.lock.unlock()
            self.colorTexture = nil
            self.depthTexture = nil
            self.textureCache = nil
            self.pointBuffer = nil
            self.lineBuffer = nil
        }
    }

    func onTextureUnregistered(_ texture: FlutterTexture) {
        dispose()
    }

    private func recreateRenderTargets() {
        let width = scaledWidth
        let height = scaledHeight
        guard width > 0, height > 0 else { return }

        let attributes: [CFString: Any] = [
            kCVPixelBufferMetalCompatibilityKey: true,
            kCVPixelBufferCGImageCompatibilityKey: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey: true,
            kCVPixelBufferIOSurfacePropertiesKey: [:]
        ]

        var nextPixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32BGRA,
            attributes as CFDictionary,
            &nextPixelBuffer
        )
        guard status == kCVReturnSuccess, let nextPixelBuffer else {
            return
        }

        guard let textureCache else { return }
        CVMetalTextureCacheFlush(textureCache, 0)

        var nextColorTexture: CVMetalTexture?
        let textureStatus = CVMetalTextureCacheCreateTextureFromImage(
            kCFAllocatorDefault,
            textureCache,
            nextPixelBuffer,
            nil,
            .bgra8Unorm,
            width,
            height,
            0,
            &nextColorTexture
        )
        guard textureStatus == kCVReturnSuccess, let nextColorTexture else {
            return
        }

        let depthDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .depth32Float,
            width: width,
            height: height,
            mipmapped: false
        )
        depthDescriptor.storageMode = .private
        depthDescriptor.usage = .renderTarget

        lock.lock()
        pixelBuffer = nextPixelBuffer
        lock.unlock()

        colorTexture = nextColorTexture
        depthTexture = device.makeTexture(descriptor: depthDescriptor)
    }

    private func renderFrameIfPossible() {
        guard viewportWidth > 0, viewportHeight > 0 else { return }
        if pixelBuffer == nil || colorTexture == nil || depthTexture == nil {
            recreateRenderTargets()
        }
        guard let drawableTexture = colorTexture.flatMap(CVMetalTextureGetTexture),
              let depthTexture,
              let commandBuffer = commandQueue.makeCommandBuffer() else {
            return
        }

        let passDescriptor = MTLRenderPassDescriptor()
        passDescriptor.colorAttachments[0].texture = drawableTexture
        passDescriptor.colorAttachments[0].loadAction = .clear
        passDescriptor.colorAttachments[0].storeAction = .store
        let clear = Self.clearColor(from: backgroundColor)
        passDescriptor.colorAttachments[0].clearColor = MTLClearColor(
            red: clear.r,
            green: clear.g,
            blue: clear.b,
            alpha: clear.a
        )
        passDescriptor.depthAttachment.texture = depthTexture
        passDescriptor.depthAttachment.loadAction = .clear
        passDescriptor.depthAttachment.storeAction = .dontCare
        passDescriptor.depthAttachment.clearDepth = 1.0

        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: passDescriptor) else {
            return
        }

        encoder.setDepthStencilState(depthState)
        let uniforms = buildUniforms()
        encoder.setVertexBytes([uniforms], length: MemoryLayout<RendererUniforms>.stride, index: 1)

        if lineVertexCount > 0, let lineBuffer {
            encoder.setRenderPipelineState(linePipeline)
            encoder.setVertexBuffer(lineBuffer, offset: 0, index: 0)
            encoder.drawPrimitives(type: .line, vertexStart: 0, vertexCount: lineVertexCount)
        }

        if pointCount > 0, let pointBuffer {
            encoder.setRenderPipelineState(pointPipeline)
            encoder.setVertexBuffer(pointBuffer, offset: 0, index: 0)
            encoder.drawPrimitives(type: .point, vertexStart: 0, vertexCount: pointCount)
        }

        encoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        DispatchQueue.main.async {
            self.textureRegistry.textureFrameAvailable(self.textureIdValue)
        }
    }

    private func buildUniforms() -> RendererUniforms {
        let aspect = Float(max(scaledWidth, 1)) / Float(max(scaledHeight, 1))
        let projection = simd_float4x4.perspective(
            fovY: 45.0 * .pi / 180.0,
            aspect: aspect,
            nearZ: 0.1,
            farZ: 100.0
        )
        let view = simd_float4x4.translation(x: 0, y: 0, z: -3.0 / zoom)
        let model = simd_float4x4.rotation(angle: rotationY, axis: SIMD3<Float>(0, 1, 0))
            * simd_float4x4.rotation(angle: rotationX, axis: SIMD3<Float>(1, 0, 0))
        return RendererUniforms(
            mvp: projection * view * model,
            pointSize: pointSize
        )
    }

    private func makeBuffer(from data: Data) -> MTLBuffer? {
        guard !data.isEmpty else { return nil }
        return data.withUnsafeBytes { bytes in
            guard let baseAddress = bytes.baseAddress else { return nil }
            return device.makeBuffer(bytes: baseAddress, length: data.count, options: .storageModeShared)
        }
    }

    private var scaledWidth: Int {
        max(1, Int((Float(viewportWidth) * renderScale).rounded()))
    }

    private var scaledHeight: Int {
        max(1, Int((Float(viewportHeight) * renderScale).rounded()))
    }

    private static func clearColor(from argb: UInt32) -> (r: Double, g: Double, b: Double, a: Double) {
        let a = Double((argb >> 24) & 0xFF) / 255.0
        let r = Double((argb >> 16) & 0xFF) / 255.0
        let g = Double((argb >> 8) & 0xFF) / 255.0
        let b = Double(argb & 0xFF) / 255.0
        return (r, g, b, a)
    }

    private static let vertexDescriptor: MTLVertexDescriptor = {
        let descriptor = MTLVertexDescriptor()
        descriptor.attributes[0].format = .float3
        descriptor.attributes[0].offset = 0
        descriptor.attributes[0].bufferIndex = 0
        descriptor.attributes[1].format = .float4
        descriptor.attributes[1].offset = MemoryLayout<Float>.stride * 3
        descriptor.attributes[1].bufferIndex = 0
        descriptor.layouts[0].stride = MemoryLayout<Float>.stride * 7
        descriptor.layouts[0].stepFunction = .perVertex
        return descriptor
    }()

    private static let shaderSource = """
    #include <metal_stdlib>
    using namespace metal;

    struct VertexIn {
        float3 position [[attribute(0)]];
        float4 color [[attribute(1)]];
    };

    struct RendererUniforms {
        float4x4 mvp;
        float pointSize;
    };

    struct PointVertexOut {
        float4 position [[position]];
        float4 color;
        float pointSize [[point_size]];
    };

    struct LineVertexOut {
        float4 position [[position]];
        float4 color;
    };

    vertex PointVertexOut point_vertex_main(VertexIn in [[stage_in]], constant RendererUniforms& uniforms [[buffer(1)]]) {
        PointVertexOut out;
        out.position = uniforms.mvp * float4(in.position, 1.0);
        out.color = in.color;
        out.pointSize = uniforms.pointSize;
        return out;
    }

    vertex LineVertexOut line_vertex_main(VertexIn in [[stage_in]], constant RendererUniforms& uniforms [[buffer(1)]]) {
        LineVertexOut out;
        out.position = uniforms.mvp * float4(in.position, 1.0);
        out.color = in.color;
        return out;
    }

    fragment float4 point_fragment(PointVertexOut in [[stage_in]], float2 pointCoord [[point_coord]]) {
        float2 centered = pointCoord - float2(0.5, 0.5);
        float dist = length(centered);
        if (dist > 0.5) {
            discard_fragment();
        }
        float alpha = 1.0 - smoothstep(0.42, 0.5, dist);
        return float4(in.color.rgb, in.color.a * alpha);
    }

    fragment float4 line_fragment(LineVertexOut in [[stage_in]]) {
        return in.color;
    }
    """
}

private struct RendererError: Error {
    let message: String

    var localizedDescription: String { message }
}

private struct RendererUniforms {
    var mvp: simd_float4x4
    var pointSize: Float
}

private extension simd_float4x4 {
    static func perspective(fovY: Float, aspect: Float, nearZ: Float, farZ: Float) -> simd_float4x4 {
        let yScale = 1 / tan(fovY * 0.5)
        let xScale = yScale / aspect
        let zRange = farZ - nearZ
        let zScale = -(farZ + nearZ) / zRange
        let wzScale = -2 * farZ * nearZ / zRange

        return simd_float4x4(columns: (
            SIMD4<Float>(xScale, 0, 0, 0),
            SIMD4<Float>(0, yScale, 0, 0),
            SIMD4<Float>(0, 0, zScale, -1),
            SIMD4<Float>(0, 0, wzScale, 0)
        ))
    }

    static func translation(x: Float, y: Float, z: Float) -> simd_float4x4 {
        simd_float4x4(columns: (
            SIMD4<Float>(1, 0, 0, 0),
            SIMD4<Float>(0, 1, 0, 0),
            SIMD4<Float>(0, 0, 1, 0),
            SIMD4<Float>(x, y, z, 1)
        ))
    }

    static func rotation(angle: Float, axis: SIMD3<Float>) -> simd_float4x4 {
        let normalized = simd_normalize(axis)
        let x = normalized.x
        let y = normalized.y
        let z = normalized.z
        let c = cos(angle)
        let s = sin(angle)
        let t = 1 - c

        return simd_float4x4(columns: (
            SIMD4<Float>(t * x * x + c, t * x * y + s * z, t * x * z - s * y, 0),
            SIMD4<Float>(t * x * y - s * z, t * y * y + c, t * y * z + s * x, 0),
            SIMD4<Float>(t * x * z + s * y, t * y * z - s * x, t * z * z + c, 0),
            SIMD4<Float>(0, 0, 0, 1)
        ))
    }
}
