package com.example.flutter_pcd_view

import android.graphics.SurfaceTexture
import android.opengl.EGL14
import android.opengl.EGLConfig
import android.opengl.EGLContext
import android.opengl.EGLDisplay
import android.opengl.EGLSurface
import android.opengl.GLES20
import android.opengl.Matrix
import android.os.Handler
import android.os.HandlerThread
import android.view.Surface
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.view.TextureRegistry
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.FloatBuffer
import java.util.concurrent.ConcurrentHashMap
import kotlin.math.max
import kotlin.math.roundToInt

class FlutterPcdViewPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    private lateinit var textureRegistry: TextureRegistry
    private lateinit var binaryMessenger: BinaryMessenger
    private lateinit var channel: MethodChannel
    private val rendererEntries = ConcurrentHashMap<Long, NativeRendererEntry>()

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        textureRegistry = binding.textureRegistry
        binaryMessenger = binding.binaryMessenger
        channel = MethodChannel(binaryMessenger, "flutter_pcd_view/native_renderer")
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        rendererEntries.values.forEach { it.dispose() }
        rendererEntries.clear()
        channel.setMethodCallHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "createRenderer" -> {
                val textureEntry = textureRegistry.createSurfaceTexture()
                val entry = NativeRendererEntry(binaryMessenger, textureEntry)
                rendererEntries[textureEntry.id()] = entry
                entry.renderer.updateConfig(
                    backgroundColor = call.argument<Number>("backgroundColor")?.toInt() ?: 0xFF000000.toInt(),
                    pointSize = call.argument<Number>("pointSize")?.toFloat() ?: 2f,
                    renderScale = call.argument<Number>("renderScale")?.toFloat() ?: 1f,
                )
                entry.renderer.updateCamera(
                    rotationX = call.argument<Number>("rotationX")?.toFloat() ?: -0.3f,
                    rotationY = call.argument<Number>("rotationY")?.toFloat() ?: 0.5f,
                    zoom = call.argument<Number>("zoom")?.toFloat() ?: 1f,
                )
                result.success(textureEntry.id())
            }
            else -> result.notImplemented()
        }
    }

    private inner class NativeRendererEntry(
        messenger: BinaryMessenger,
        private val textureEntry: TextureRegistry.SurfaceTextureEntry,
    ) : MethodChannel.MethodCallHandler {
        private val methodChannel = MethodChannel(
            messenger,
            "flutter_pcd_view/native_renderer/${textureEntry.id()}"
        )
        val renderer = AndroidPointCloudRenderer(textureEntry.surfaceTexture())

        init {
            methodChannel.setMethodCallHandler(this)
        }

        override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
            when (call.method) {
                "setViewport" -> {
                    val width = (call.argument<Number>("width")?.toInt() ?: 1).coerceAtLeast(1)
                    val height = (call.argument<Number>("height")?.toInt() ?: 1).coerceAtLeast(1)
                    renderer.setViewport(width, height)
                    result.success(null)
                }
                "updateConfig" -> {
                    renderer.updateConfig(
                        backgroundColor = call.argument<Number>("backgroundColor")?.toInt() ?: 0xFF000000.toInt(),
                        pointSize = call.argument<Number>("pointSize")?.toFloat() ?: 2f,
                        renderScale = call.argument<Number>("renderScale")?.toFloat() ?: 1f,
                    )
                    result.success(null)
                }
                "updateCamera" -> {
                    renderer.updateCamera(
                        rotationX = call.argument<Number>("rotationX")?.toFloat() ?: -0.3f,
                        rotationY = call.argument<Number>("rotationY")?.toFloat() ?: 0.5f,
                        zoom = call.argument<Number>("zoom")?.toFloat() ?: 1f,
                    )
                    result.success(null)
                }
                "loadPackedScene" -> {
                    renderer.loadScene(
                        pointBytes = call.argument<ByteArray>("points") ?: ByteArray(0),
                        pointCount = call.argument<Number>("pointCount")?.toInt() ?: 0,
                        lineBytes = call.argument<ByteArray>("lines") ?: ByteArray(0),
                        lineVertexCount = call.argument<Number>("lineVertexCount")?.toInt() ?: 0,
                    )
                    result.success(null)
                }
                "dispose" -> {
                    dispose()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        fun dispose() {
            methodChannel.setMethodCallHandler(null)
            renderer.dispose()
            textureEntry.release()
            rendererEntries.remove(textureEntry.id())
        }
    }
}

private class AndroidPointCloudRenderer(
    private val surfaceTexture: SurfaceTexture,
) {
    private val renderThread = HandlerThread("FlutterPcdViewRenderer").apply { start() }
    private val handler = Handler(renderThread.looper)

    private var surface: Surface? = null
    private var eglDisplay: EGLDisplay = EGL14.EGL_NO_DISPLAY
    private var eglContext: EGLContext = EGL14.EGL_NO_CONTEXT
    private var eglSurface: EGLSurface = EGL14.EGL_NO_SURFACE
    private var eglConfig: EGLConfig? = null

    private var viewportWidth: Int = 1
    private var viewportHeight: Int = 1
    private var pointProgram: Int = 0
    private var lineProgram: Int = 0
    private var pointBuffer: FloatBuffer? = null
    private var lineBuffer: FloatBuffer? = null
    private var pointCount: Int = 0
    private var lineVertexCount: Int = 0
    private var pointSize: Float = 2f
    private var renderScale: Float = 1f
    private var backgroundColor: Int = 0xFF000000.toInt()
    private var rotationX: Float = -0.3f
    private var rotationY: Float = 0.5f
    private var zoom: Float = 1f
    private val projectionMatrix = FloatArray(16)
    private val viewMatrix = FloatArray(16)
    private val modelMatrix = FloatArray(16)
    private val pvMatrix = FloatArray(16)
    private val mvpMatrix = FloatArray(16)

    init {
        handler.post {
            initEgl()
            initGl()
            drawFrame()
        }
    }

    fun setViewport(width: Int, height: Int) {
        handler.post {
            viewportWidth = width
            viewportHeight = height
            applyBufferSize()
            drawFrame()
        }
    }

    fun updateConfig(backgroundColor: Int, pointSize: Float, renderScale: Float) {
        handler.post {
            this.backgroundColor = backgroundColor
            this.pointSize = pointSize
            this.renderScale = renderScale.coerceIn(0.5f, 2.0f)
            applyBufferSize()
            drawFrame()
        }
    }

    fun updateCamera(rotationX: Float, rotationY: Float, zoom: Float) {
        handler.post {
            this.rotationX = rotationX
            this.rotationY = rotationY
            this.zoom = max(zoom, 0.05f)
            drawFrame()
        }
    }

    fun loadScene(
        pointBytes: ByteArray,
        pointCount: Int,
        lineBytes: ByteArray,
        lineVertexCount: Int,
    ) {
        handler.post {
            this.pointBuffer = pointBytes.toDirectFloatBuffer()
            this.lineBuffer = lineBytes.toDirectFloatBuffer()
            this.pointCount = pointCount
            this.lineVertexCount = lineVertexCount
            drawFrame()
        }
    }

    fun dispose() {
        handler.post {
            releaseGl()
            renderThread.quitSafely()
        }
    }

    private fun initEgl() {
        surface = Surface(surfaceTexture)
        eglDisplay = EGL14.eglGetDisplay(EGL14.EGL_DEFAULT_DISPLAY)
        val version = IntArray(2)
        EGL14.eglInitialize(eglDisplay, version, 0, version, 1)

        val configAttributes = intArrayOf(
            EGL14.EGL_RENDERABLE_TYPE, EGL14.EGL_OPENGL_ES2_BIT,
            EGL14.EGL_RED_SIZE, 8,
            EGL14.EGL_GREEN_SIZE, 8,
            EGL14.EGL_BLUE_SIZE, 8,
            EGL14.EGL_ALPHA_SIZE, 8,
            EGL14.EGL_DEPTH_SIZE, 16,
            EGL14.EGL_NONE,
        )
        val configs = arrayOfNulls<EGLConfig>(1)
        val numConfigs = IntArray(1)
        EGL14.eglChooseConfig(
            eglDisplay,
            configAttributes,
            0,
            configs,
            0,
            1,
            numConfigs,
            0,
        )
        eglConfig = configs[0]

        val contextAttributes = intArrayOf(
            EGL14.EGL_CONTEXT_CLIENT_VERSION, 2,
            EGL14.EGL_NONE,
        )
        eglContext = EGL14.eglCreateContext(
            eglDisplay,
            eglConfig,
            EGL14.EGL_NO_CONTEXT,
            contextAttributes,
            0,
        )
        val surfaceAttributes = intArrayOf(EGL14.EGL_NONE)
        eglSurface = EGL14.eglCreateWindowSurface(
            eglDisplay,
            eglConfig,
            surface,
            surfaceAttributes,
            0,
        )
        EGL14.eglMakeCurrent(eglDisplay, eglSurface, eglSurface, eglContext)
    }

    private fun initGl() {
        pointProgram = createProgram(VERTEX_SHADER, POINT_FRAGMENT_SHADER)
        lineProgram = createProgram(VERTEX_SHADER, LINE_FRAGMENT_SHADER)
        GLES20.glEnable(GLES20.GL_DEPTH_TEST)
    }

    private fun applyBufferSize() {
        val scaledWidth = max(1, (viewportWidth * renderScale).roundToInt())
        val scaledHeight = max(1, (viewportHeight * renderScale).roundToInt())
        surfaceTexture.setDefaultBufferSize(scaledWidth, scaledHeight)
    }

    private fun drawFrame() {
        if (eglDisplay == EGL14.EGL_NO_DISPLAY || eglSurface == EGL14.EGL_NO_SURFACE) return
        EGL14.eglMakeCurrent(eglDisplay, eglSurface, eglSurface, eglContext)
        val scaledWidth = max(1, (viewportWidth * renderScale).roundToInt())
        val scaledHeight = max(1, (viewportHeight * renderScale).roundToInt())
        GLES20.glViewport(0, 0, scaledWidth, scaledHeight)

        val alpha = ((backgroundColor ushr 24) and 0xFF) / 255f
        val red = ((backgroundColor ushr 16) and 0xFF) / 255f
        val green = ((backgroundColor ushr 8) and 0xFF) / 255f
        val blue = (backgroundColor and 0xFF) / 255f
        GLES20.glClearColor(red, green, blue, alpha)
        GLES20.glClear(GLES20.GL_COLOR_BUFFER_BIT or GLES20.GL_DEPTH_BUFFER_BIT)

        val aspect = scaledWidth.toFloat() / scaledHeight.coerceAtLeast(1).toFloat()
        Matrix.perspectiveM(projectionMatrix, 0, 45f, aspect, 0.1f, 100f)
        Matrix.setIdentityM(viewMatrix, 0)
        Matrix.translateM(viewMatrix, 0, 0f, 0f, -3f / zoom)
        Matrix.setIdentityM(modelMatrix, 0)
        Matrix.rotateM(modelMatrix, 0, Math.toDegrees(rotationX.toDouble()).toFloat(), 1f, 0f, 0f)
        Matrix.rotateM(modelMatrix, 0, Math.toDegrees(rotationY.toDouble()).toFloat(), 0f, 1f, 0f)
        Matrix.multiplyMM(pvMatrix, 0, projectionMatrix, 0, viewMatrix, 0)
        Matrix.multiplyMM(mvpMatrix, 0, pvMatrix, 0, modelMatrix, 0)

        lineBuffer?.let { drawLines(it) }
        pointBuffer?.let { drawPoints(it) }
        EGL14.eglSwapBuffers(eglDisplay, eglSurface)
    }

    private fun drawPoints(buffer: FloatBuffer) {
        if (pointCount <= 0) return
        GLES20.glUseProgram(pointProgram)
        val positionHandle = GLES20.glGetAttribLocation(pointProgram, "aPosition")
        val colorHandle = GLES20.glGetAttribLocation(pointProgram, "aColor")
        val mvpHandle = GLES20.glGetUniformLocation(pointProgram, "uMvpMatrix")
        val pointSizeHandle = GLES20.glGetUniformLocation(pointProgram, "uPointSize")

        buffer.position(0)
        GLES20.glVertexAttribPointer(positionHandle, 3, GLES20.GL_FLOAT, false, 7 * 4, buffer)
        GLES20.glEnableVertexAttribArray(positionHandle)
        buffer.position(3)
        GLES20.glVertexAttribPointer(colorHandle, 4, GLES20.GL_FLOAT, false, 7 * 4, buffer)
        GLES20.glEnableVertexAttribArray(colorHandle)
        GLES20.glUniformMatrix4fv(mvpHandle, 1, false, mvpMatrix, 0)
        GLES20.glUniform1f(pointSizeHandle, pointSize)
        GLES20.glDrawArrays(GLES20.GL_POINTS, 0, pointCount)
    }

    private fun drawLines(buffer: FloatBuffer) {
        if (lineVertexCount <= 0) return
        GLES20.glUseProgram(lineProgram)
        val positionHandle = GLES20.glGetAttribLocation(lineProgram, "aPosition")
        val colorHandle = GLES20.glGetAttribLocation(lineProgram, "aColor")
        val mvpHandle = GLES20.glGetUniformLocation(lineProgram, "uMvpMatrix")

        buffer.position(0)
        GLES20.glVertexAttribPointer(positionHandle, 3, GLES20.GL_FLOAT, false, 7 * 4, buffer)
        GLES20.glEnableVertexAttribArray(positionHandle)
        buffer.position(3)
        GLES20.glVertexAttribPointer(colorHandle, 4, GLES20.GL_FLOAT, false, 7 * 4, buffer)
        GLES20.glEnableVertexAttribArray(colorHandle)
        GLES20.glUniformMatrix4fv(mvpHandle, 1, false, mvpMatrix, 0)
        GLES20.glDrawArrays(GLES20.GL_LINES, 0, lineVertexCount)
    }

    private fun createProgram(vertexShaderSource: String, fragmentShaderSource: String): Int {
        val vertexShader = loadShader(GLES20.GL_VERTEX_SHADER, vertexShaderSource)
        val fragmentShader = loadShader(GLES20.GL_FRAGMENT_SHADER, fragmentShaderSource)
        val program = GLES20.glCreateProgram()
        GLES20.glAttachShader(program, vertexShader)
        GLES20.glAttachShader(program, fragmentShader)
        GLES20.glLinkProgram(program)
        return program
    }

    private fun loadShader(type: Int, shaderSource: String): Int {
        val shader = GLES20.glCreateShader(type)
        GLES20.glShaderSource(shader, shaderSource)
        GLES20.glCompileShader(shader)
        return shader
    }

    private fun releaseGl() {
        if (eglDisplay != EGL14.EGL_NO_DISPLAY) {
            EGL14.eglMakeCurrent(
                eglDisplay,
                EGL14.EGL_NO_SURFACE,
                EGL14.EGL_NO_SURFACE,
                EGL14.EGL_NO_CONTEXT,
            )
            if (eglSurface != EGL14.EGL_NO_SURFACE) {
                EGL14.eglDestroySurface(eglDisplay, eglSurface)
            }
            if (eglContext != EGL14.EGL_NO_CONTEXT) {
                EGL14.eglDestroyContext(eglDisplay, eglContext)
            }
            EGL14.eglTerminate(eglDisplay)
        }
        surface?.release()
        eglDisplay = EGL14.EGL_NO_DISPLAY
        eglContext = EGL14.EGL_NO_CONTEXT
        eglSurface = EGL14.EGL_NO_SURFACE
    }

    private companion object {
        const val VERTEX_SHADER = """
            uniform mat4 uMvpMatrix;
            uniform float uPointSize;
            attribute vec3 aPosition;
            attribute vec4 aColor;
            varying vec4 vColor;
            void main() {
              gl_Position = uMvpMatrix * vec4(aPosition, 1.0);
              gl_PointSize = uPointSize;
              vColor = aColor;
            }
        """

        const val POINT_FRAGMENT_SHADER = """
            precision mediump float;
            varying vec4 vColor;
            void main() {
              vec2 centered = gl_PointCoord - vec2(0.5, 0.5);
              float dist = length(centered);
              if (dist > 0.5) {
                discard;
              }
              float alpha = 1.0 - smoothstep(0.42, 0.5, dist);
              gl_FragColor = vec4(vColor.rgb, vColor.a * alpha);
            }
        """

        const val LINE_FRAGMENT_SHADER = """
            precision mediump float;
            varying vec4 vColor;
            void main() {
              gl_FragColor = vColor;
            }
        """
    }
}

private fun ByteArray.toDirectFloatBuffer(): FloatBuffer {
    val byteBuffer = ByteBuffer.allocateDirect(size).order(ByteOrder.nativeOrder())
    byteBuffer.put(this)
    byteBuffer.position(0)
    return byteBuffer.asFloatBuffer()
}
