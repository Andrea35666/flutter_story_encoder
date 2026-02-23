package com.lucasveneno.flutter_story_encoder

import android.media.MediaCodec
import android.media.MediaCodecInfo
import android.media.MediaFormat
import android.media.MediaMuxer
import android.view.Surface
import io.flutter.embedding.engine.plugins.FlutterPlugin
import java.io.File
import java.util.concurrent.Executors

class FlutterStoryEncoderPlugin : FlutterPlugin, StoryEncoderHostApi {
    private var mediaCodec: MediaCodec? = null
    private var mediaMuxer: MediaMuxer? = null
    private var inputSurface: Surface? = null
    private var videoTrackIndex = -1
    private var isEncoding = false
    private val executor = Executors.newSingleThreadExecutor()

    private var flutterApi: StoryEncoderFlutterApi? = null
    private var config: EncoderConfig? = null
    private var framesProcessed: Long = 0

    private var renderer: OpenGLRenderer? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        StoryEncoderHostApi.setUp(binding.binaryMessenger, this)
        flutterApi = StoryEncoderFlutterApi(binding.binaryMessenger)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        StoryEncoderHostApi.setUp(binding.binaryMessenger, null)
    }

    override fun start(config: EncoderConfig, callback: (Result<Boolean>) -> Unit) {
        executor.execute {
            try {
                this.config = config
                this.framesProcessed = 0

                val format =
                        MediaFormat.createVideoFormat(
                                MediaFormat.MIMETYPE_VIDEO_AVC,
                                config.width.toInt(),
                                config.height.toInt()
                        )
                format.setInteger(
                        MediaFormat.KEY_COLOR_FORMAT,
                        MediaCodecInfo.CodecCapabilities.COLOR_FormatSurface
                )
                format.setInteger(MediaFormat.KEY_BIT_RATE, config.bitrate.toInt())
                format.setInteger(MediaFormat.KEY_FRAME_RATE, config.fps.toInt())
                format.setInteger(MediaFormat.KEY_I_FRAME_INTERVAL, 1)
                format.setInteger(
                        MediaFormat.KEY_PROFILE,
                        MediaCodecInfo.CodecProfileLevel.AVCProfileHigh
                )
                format.setInteger(
                        MediaFormat.KEY_LEVEL,
                        MediaCodecInfo.CodecProfileLevel.AVCLevel41
                )

                mediaCodec = MediaCodec.createEncoderByType(MediaFormat.MIMETYPE_VIDEO_AVC)
                mediaCodec?.configure(format, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
                inputSurface = mediaCodec?.createInputSurface()
                mediaCodec?.start()

                renderer =
                        OpenGLRenderer(inputSurface!!, config.width.toInt(), config.height.toInt())

                val file = File(config.outputPath)
                if (file.exists()) file.delete()
                mediaMuxer =
                        MediaMuxer(config.outputPath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)

                isEncoding = true
                callback(Result.success(true))
            } catch (e: Exception) {
                callback(Result.failure(e))
            }
        }
    }

    override fun appendFrame(rgbaData: ByteArray, callback: (Result<Boolean>) -> Unit) {
        if (!isEncoding) {
            callback(Result.success(false))
            return
        }

        executor.execute {
            try {
                drainEncoder(false)

                // Deterministic PTS calculation (in nanoseconds for EGL)
                val ptsNs = framesProcessed * 1000000000L / (config?.fps ?: 30)
                renderer?.render(rgbaData, ptsNs)

                framesProcessed++

                val stats = EncodingStats(framesProcessed, config?.fps?.toDouble() ?: 30.0, 0.0)
                flutterApi?.onProgress(stats) {}

                callback(Result.success(true))
            } catch (e: Exception) {
                callback(Result.failure(e))
            }
        }
    }

    private fun drainEncoder(endOfStream: Boolean) {
        if (endOfStream) {
            mediaCodec?.signalEndOfInputStream()
        }

        val bufferInfo = MediaCodec.BufferInfo()
        while (true) {
            val encoderStatus = mediaCodec?.dequeueOutputBuffer(bufferInfo, 5000) ?: break

            if (encoderStatus == MediaCodec.INFO_TRY_AGAIN_LATER) {
                if (!endOfStream) break
            } else if (encoderStatus == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED) {
                val newFormat = mediaCodec?.outputFormat
                videoTrackIndex = mediaMuxer?.addTrack(newFormat!!) ?: -1
                mediaMuxer?.start()
            } else if (encoderStatus >= 0) {
                val encodedData = mediaCodec?.getOutputBuffer(encoderStatus)
                if (encodedData != null) {
                    if (bufferInfo.size != 0) {
                        encodedData.position(bufferInfo.offset)
                        encodedData.limit(bufferInfo.offset + bufferInfo.size)
                        mediaMuxer?.writeSampleData(videoTrackIndex, encodedData, bufferInfo)
                    }

                    mediaCodec?.releaseOutputBuffer(encoderStatus, false)
                    if (bufferInfo.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) break
                }
            }
        }
    }

    override fun finish(callback: (Result<String?>) -> Unit) {
        executor.execute {
            try {
                drainEncoder(true)
                isEncoding = false
                mediaCodec?.stop()
                mediaCodec?.release()
                mediaMuxer?.stop()
                mediaMuxer?.release()
                renderer?.release()

                callback(Result.success(config?.outputPath))
            } catch (e: Exception) {
                callback(Result.failure(e))
            }
        }
    }

    override fun cancel() {
        executor.execute {
            isEncoding = false
            mediaEncoderCleanup()
        }
    }

    private fun mediaEncoderCleanup() {
        try {
            mediaCodec?.stop()
            mediaCodec?.release()
            mediaMuxer?.release()
            renderer?.release()
        } catch (e: Exception) {}
    }
}
