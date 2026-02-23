package com.lucasveneno.flutter_story_encoder

import android.media.MediaCodec
import android.media.MediaCodecInfo
import android.media.MediaFormat
import android.media.MediaMuxer
import android.os.Handler
import android.os.Looper
import android.view.Surface
import io.flutter.embedding.engine.plugins.FlutterPlugin
import java.io.File
import java.util.concurrent.Executors

class FlutterStoryEncoderPlugin : FlutterPlugin, StoryEncoderHostApi {
    private var mediaCodec: MediaCodec? = null
    private var audioCodec: MediaCodec? = null
    private var mediaMuxer: MediaMuxer? = null
    private var inputSurface: Surface? = null
    private var videoTrackIndex = -1
    private var audioTrackIndex = -1
    private var isEncoding = false
    private val executor = Executors.newSingleThreadExecutor()

    private var flutterApi: StoryEncoderFlutterApi? = null
    private var config: EncoderConfig? = null
    private var videoFramesProcessed: Long = 0
    private var audioBytesGenerated: Long = 0

    private var renderer: OpenGLRenderer? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        StoryEncoderHostApi.setUp(binding.binaryMessenger, this)
        flutterApi = StoryEncoderFlutterApi(binding.binaryMessenger)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        StoryEncoderHostApi.setUp(binding.binaryMessenger, null)
        executor.shutdown()
    }

    override fun start(config: EncoderConfig, callback: (Result<Boolean>) -> Unit) {
        val mainHandler = Handler(Looper.getMainLooper())
        executor.execute {
            try {
                this.config = config
                this.videoFramesProcessed = 0
                this.audioBytesGenerated = 0

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

                if (config.addSilentAudio) {
                    val audioFormat =
                            MediaFormat.createAudioFormat(MediaFormat.MIMETYPE_AUDIO_AAC, 44100, 2)
                    audioFormat.setInteger(MediaFormat.KEY_BIT_RATE, 128000)
                    audioFormat.setInteger(
                            MediaFormat.KEY_AAC_PROFILE,
                            MediaCodecInfo.CodecProfileLevel.AACObjectLC
                    )
                    audioCodec = MediaCodec.createEncoderByType(MediaFormat.MIMETYPE_AUDIO_AAC)
                    audioCodec?.configure(audioFormat, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
                    audioCodec?.start()
                }

                renderer =
                        OpenGLRenderer(inputSurface!!, config.width.toInt(), config.height.toInt())

                val file = File(config.outputPath)
                if (file.exists()) file.delete()
                mediaMuxer =
                        MediaMuxer(config.outputPath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)

                isEncoding = true
                mainHandler.post { callback(Result.success(true)) }
            } catch (e: Exception) {
                mainHandler.post { callback(Result.failure(e)) }
            }
        }
    }

    override fun appendFrame(rgbaData: ByteArray, callback: (Result<Boolean>) -> Unit) {
        val mainHandler = Handler(Looper.getMainLooper())
        if (!isEncoding) {
            mainHandler.post { callback(Result.success(false)) }
            return
        }

        executor.execute {
            try {
                drainEncoder(false)

                // Deterministic PTS calculation (in nanoseconds for EGL)
                val ptsNs = videoFramesProcessed * 1000000000L / (config?.fps ?: 30)
                renderer?.render(rgbaData, ptsNs)

                videoFramesProcessed++

                if (config?.addSilentAudio == true) {
                    feedSilentAudio(ptsNs)
                }

                val stats =
                        EncodingStats(videoFramesProcessed, config?.fps?.toDouble() ?: 30.0, 0.0)
                mainHandler.post {
                    flutterApi?.onProgress(stats) {}
                    callback(Result.success(true))
                }
            } catch (e: Exception) {
                mainHandler.post { callback(Result.failure(e)) }
            }
        }
    }

    private fun drainEncoder(endOfStream: Boolean) {
        if (endOfStream) {
            mediaCodec?.signalEndOfInputStream()
            audioCodec?.let {
                val inputIndex = it.dequeueInputBuffer(5000)
                if (inputIndex >= 0) {
                    it.queueInputBuffer(inputIndex, 0, 0, 0, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
                }
            }
        }

        drainCodec(mediaCodec, true)
        if (config?.addSilentAudio == true) {
            drainCodec(audioCodec, false)
        }
    }

    private fun drainCodec(codec: MediaCodec?, isVideo: Boolean) {
        val bufferInfo = MediaCodec.BufferInfo()
        while (true) {
            val encoderStatus = codec?.dequeueOutputBuffer(bufferInfo, 5000) ?: break

            if (encoderStatus == MediaCodec.INFO_TRY_AGAIN_LATER) {
                break
            } else if (encoderStatus == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED) {
                val newFormat = codec.outputFormat
                if (isVideo) {
                    videoTrackIndex = mediaMuxer?.addTrack(newFormat) ?: -1
                } else {
                    audioTrackIndex = mediaMuxer?.addTrack(newFormat) ?: -1
                }

                if (videoTrackIndex != -1 && (!config!!.addSilentAudio || audioTrackIndex != -1)) {
                    mediaMuxer?.start()
                }
            } else if (encoderStatus >= 0) {
                val encodedData = codec.getOutputBuffer(encoderStatus)
                if (encodedData != null) {
                    if (bufferInfo.size != 0) {
                        encodedData.position(bufferInfo.offset)
                        encodedData.limit(bufferInfo.offset + bufferInfo.size)
                        val trackIndex = if (isVideo) videoTrackIndex else audioTrackIndex
                        mediaMuxer?.writeSampleData(trackIndex, encodedData, bufferInfo)
                    }

                    codec.releaseOutputBuffer(encoderStatus, false)
                    if (bufferInfo.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) break
                }
            }
        }
    }

    private fun feedSilentAudio(ptsNs: Long) {
        val codec = audioCodec ?: return
        val inputIndex = codec.dequeueInputBuffer(5000)
        if (inputIndex >= 0) {
            val inputBuffer = codec.getInputBuffer(inputIndex)
            inputBuffer?.clear()
            val size = inputBuffer?.remaining() ?: 0
            val silentData = ByteArray(size)
            inputBuffer?.put(silentData)
            codec.queueInputBuffer(inputIndex, 0, size, ptsNs / 1000, 0)
        }
    }

    override fun finish(callback: (Result<String?>) -> Unit) {
        val mainHandler = Handler(Looper.getMainLooper())
        executor.execute {
            try {
                drainEncoder(true)
                isEncoding = false

                mediaEncoderCleanup()

                mainHandler.post { callback(Result.success(config?.outputPath)) }
            } catch (e: Exception) {
                mainHandler.post { callback(Result.failure(e)) }
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
        } catch (e: Exception) {}
        mediaCodec = null

        try {
            audioCodec?.stop()
            audioCodec?.release()
        } catch (e: Exception) {}
        audioCodec = null

        try {
            mediaMuxer?.stop()
            mediaMuxer?.release()
        } catch (e: Exception) {}
        mediaMuxer = null

        try {
            renderer?.release()
        } catch (e: Exception) {}
        renderer = null

        inputSurface = null
        videoTrackIndex = -1
        audioTrackIndex = -1
    }
}
