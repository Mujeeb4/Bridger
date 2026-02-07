package com.bridge.phone.call

import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.AudioTrack
import android.media.MediaRecorder
import android.os.Process
import android.util.Log
import java.io.IOException

class AudioStreamManager(private val listener: AudioStreamListener) {

    interface AudioStreamListener {
        fun onAudioDataCaptured(data: ByteArray)
    }

    companion object {
        private const val TAG = "AudioStreamManager"
        private const val SAMPLE_RATE = 16000
        private const val CHANNEL_CONFIG_IN = AudioFormat.CHANNEL_IN_MONO
        private const val CHANNEL_CONFIG_OUT = AudioFormat.CHANNEL_OUT_MONO
        private const val AUDIO_FORMAT = AudioFormat.ENCODING_PCM_16BIT
    }

    private var audioRecord: AudioRecord? = null
    private var audioTrack: AudioTrack? = null
    private var isStreaming = false
    private var recordingThread: Thread? = null

    // Buffers
    private var minBufferSizeIn = 0
    private var minBufferSizeOut = 0

    init {
        minBufferSizeIn = AudioRecord.getMinBufferSize(SAMPLE_RATE, CHANNEL_CONFIG_IN, AUDIO_FORMAT)
        minBufferSizeOut = AudioTrack.getMinBufferSize(SAMPLE_RATE, CHANNEL_CONFIG_OUT, AUDIO_FORMAT)
    }

    fun startStreaming() {
        if (isStreaming) return

        startRecording()
        startPlayback()
        isStreaming = true
    }

    fun stopStreaming() {
        isStreaming = false
        stopRecording()
        stopPlayback()
    }

    private fun startRecording() {
        try {
            audioRecord = AudioRecord(
                MediaRecorder.AudioSource.VOICE_COMMUNICATION, // Optimized for VoIP
                SAMPLE_RATE,
                CHANNEL_CONFIG_IN,
                AUDIO_FORMAT,
                minBufferSizeIn * 2
            )

            if (audioRecord?.state != AudioRecord.STATE_INITIALIZED) {
                Log.e(TAG, "AudioRecord failed to initialize")
                return
            }

            audioRecord?.startRecording()
            
            recordingThread = Thread {
                Process.setThreadPriority(Process.THREAD_PRIORITY_AUDIO)
                val buffer = ByteArray(640) // ~40ms chunk at 16kHz 16bit mono (16000 * 2 * 0.02 = 640)
                
                while (isStreaming && audioRecord != null) {
                    val read = audioRecord?.read(buffer, 0, buffer.size) ?: 0
                    if (read > 0) {
                        val validData = buffer.copyOfRange(0, read)
                        listener.onAudioDataCaptured(validData)
                    }
                }
            }
            recordingThread?.start()
            
        } catch (e: Exception) {
            Log.e(TAG, "Error starting recording", e)
        }
    }

    private fun stopRecording() {
        try {
            audioRecord?.stop()
            audioRecord?.release()
            audioRecord = null
            recordingThread = null
        } catch (e: Exception) {
            Log.e(TAG, "Error stopping recording", e)
        }
    }

    private fun startPlayback() {
        try {
            audioTrack = AudioTrack.Builder()
                .setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_VOICE_COMMUNICATION)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                        .build()
                )
                .setAudioFormat(
                    AudioFormat.Builder()
                        .setEncoding(AUDIO_FORMAT)
                        .setSampleRate(SAMPLE_RATE)
                        .setChannelMask(CHANNEL_CONFIG_OUT)
                        .build()
                )
                .setBufferSizeInBytes(minBufferSizeOut * 2)
                .setTransferMode(AudioTrack.MODE_STREAM)
                .build()

            audioTrack?.play()
        } catch (e: Exception) {
            Log.e(TAG, "Error starting playback", e)
        }
    }

    private fun stopPlayback() {
        try {
            audioTrack?.stop()
            audioTrack?.release()
            audioTrack = null
        } catch (e: Exception) {
            Log.e(TAG, "Error stopping playback", e)
        }
    }

    fun playAudioChunk(data: ByteArray) {
        if (audioTrack != null && audioTrack?.playState == AudioTrack.PLAYSTATE_PLAYING) {
            audioTrack?.write(data, 0, data.size)
        }
    }
}
