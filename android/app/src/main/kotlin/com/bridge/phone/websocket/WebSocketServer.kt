package com.bridge.phone.websocket

import android.os.Handler
import android.os.Looper
import android.util.Base64
import android.util.Log
import org.json.JSONObject
import java.io.BufferedReader
import java.io.InputStreamReader
import java.io.OutputStream
import java.net.ServerSocket
import java.net.Socket
import java.security.MessageDigest
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import kotlin.experimental.xor

/**
 * Simple WebSocket server for device-to-device communication.
 * Embedded implementation without external dependencies.
 */
class WebSocketServer(private val port: Int = DEFAULT_PORT) {

    companion object {
        private const val TAG = "WebSocketServer"
        const val DEFAULT_PORT = 8765
        private const val WS_MAGIC_STRING = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"
    }

    private var serverSocket: ServerSocket? = null
    private var isRunning = false
    private val clients = ConcurrentHashMap<String, ClientConnection>()
    private val executorService: ExecutorService = Executors.newCachedThreadPool()
    private val mainHandler = Handler(Looper.getMainLooper())

    var callback: WebSocketCallback? = null

    // ========================================================================
    // Server Control
    // ========================================================================

    fun start() {
        if (isRunning) {
            Log.d(TAG, "Server already running")
            return
        }

        executorService.execute {
            try {
                serverSocket = ServerSocket(port)
                isRunning = true
                Log.d(TAG, "WebSocket server started on port $port")
                
                mainHandler.post {
                    callback?.onServerStarted(port)
                }

                while (isRunning) {
                    try {
                        val clientSocket = serverSocket?.accept() ?: break
                        handleNewConnection(clientSocket)
                    } catch (e: Exception) {
                        if (isRunning) {
                            Log.e(TAG, "Error accepting connection", e)
                        }
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error starting server", e)
                mainHandler.post {
                    callback?.onError("Failed to start server: ${e.message}")
                }
            }
        }
    }

    fun stop() {
        isRunning = false
        clients.values.forEach { it.close() }
        clients.clear()
        
        try {
            serverSocket?.close()
        } catch (e: Exception) {
            Log.e(TAG, "Error closing server socket", e)
        }
        serverSocket = null
        
        Log.d(TAG, "WebSocket server stopped")
        callback?.onServerStopped()
    }

    fun isRunning(): Boolean = isRunning

    // ========================================================================
    // Client Management
    // ========================================================================

    private fun handleNewConnection(socket: Socket) {
        executorService.execute {
            try {
                val clientId = socket.inetAddress.hostAddress ?: "unknown"
                Log.d(TAG, "New connection from $clientId")
                
                if (performHandshake(socket)) {
                    val connection = ClientConnection(clientId, socket)
                    clients[clientId] = connection
                    
                    mainHandler.post {
                        callback?.onClientConnected(clientId)
                    }
                    
                    // Start reading loop
                    readMessages(connection)
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error handling connection", e)
            }
        }
    }

    private fun performHandshake(socket: Socket): Boolean {
        try {
            val reader = BufferedReader(InputStreamReader(socket.getInputStream()))
            val output = socket.getOutputStream()
            
            // Read HTTP request
            val requestLines = mutableListOf<String>()
            var line: String?
            while (reader.readLine().also { line = it } != null && line != "") {
                requestLines.add(line!!)
            }
            
            // Find WebSocket key
            val keyLine = requestLines.find { it.startsWith("Sec-WebSocket-Key:") }
            val key = keyLine?.substringAfter(":")?.trim() ?: return false
            
            // Generate accept key
            val acceptKey = generateAcceptKey(key)
            
            // Send handshake response
            val response = "HTTP/1.1 101 Switching Protocols\r\n" +
                    "Upgrade: websocket\r\n" +
                    "Connection: Upgrade\r\n" +
                    "Sec-WebSocket-Accept: $acceptKey\r\n\r\n"
            
            output.write(response.toByteArray())
            output.flush()
            
            Log.d(TAG, "WebSocket handshake completed")
            return true
        } catch (e: Exception) {
            Log.e(TAG, "Handshake failed", e)
            return false
        }
    }

    private fun generateAcceptKey(key: String): String {
        val combined = key + WS_MAGIC_STRING
        val sha1 = MessageDigest.getInstance("SHA-1").digest(combined.toByteArray())
        return Base64.encodeToString(sha1, Base64.NO_WRAP)
    }

    private fun readMessages(connection: ClientConnection) {
        try {
            val input = connection.socket.getInputStream()
            
            while (isRunning && !connection.socket.isClosed) {
                val message = readFrame(input)
                if (message != null) {
                    mainHandler.post {
                        callback?.onMessageReceived(connection.id, message)
                    }
                }
            }
        } catch (e: Exception) {
            Log.d(TAG, "Client ${connection.id} disconnected")
        } finally {
            clients.remove(connection.id)
            mainHandler.post {
                callback?.onClientDisconnected(connection.id)
            }
        }
    }

    private fun readFrame(input: java.io.InputStream): String? {
        try {
                            val firstByte = input.read()
            if (firstByte == -1) return null
            
            val opcode = firstByte and 0x0F
            if (opcode == 0x8) { // Close frame
                return null
            }
            
            val secondByte = input.read()
            if (secondByte == -1) return null
            
            val masked = (secondByte and 0x80) != 0
            var payloadLength = (secondByte and 0x7F).toLong()
            
            // Extended payload length
            if (payloadLength == 126L) {
                payloadLength = ((input.read() shl 8) or input.read()).toLong()
            } else if (payloadLength == 127L) {
                payloadLength = 0
                for (i in 0..7) {
                    payloadLength = (payloadLength shl 8) or input.read().toLong()
                }
            }
            
            // Read mask
            val mask = if (masked) {
                ByteArray(4) { input.read().toByte() }
            } else null
            
            // Read payload
            val payload = ByteArray(payloadLength.toInt())
            var bytesRead = 0
            while (bytesRead < payloadLength) {
                val read = input.read(payload, bytesRead, (payloadLength - bytesRead).toInt())
                if (read == -1) break
                bytesRead += read
            }
            
            // Unmask
            if (mask != null) {
                for (i in payload.indices) {
                    payload[i] = payload[i] xor mask[i % 4]
                }
            }
            
            if (opcode == 0x1) { // Text
                callback?.onMessageReceived(connection.id, String(payload))
            } else if (opcode == 0x2) { // Binary
                callback?.onBinaryMessageReceived(connection.id, payload)
            }
            
            // Return dummy non-null to keep loop alive, processing is done via callback
            return "processed"
        } catch (e: Exception) {
            return null
        }
    }

    // ========================================================================
    // Sending Messages
    // ========================================================================

    fun sendMessage(clientId: String, message: String) {
        val connection = clients[clientId] ?: return
        sendToClient(connection, message.toByteArray(), 0x1) // Text
    }

    fun sendBinary(clientId: String, data: ByteArray) {
        val connection = clients[clientId] ?: return
        sendToClient(connection, data, 0x2) // Binary
    }

    fun broadcast(message: String) {
        clients.values.forEach { sendToClient(it, message.toByteArray(), 0x1) }
    }

    fun broadcastBinary(data: ByteArray) {
        clients.values.forEach { sendToClient(it, data, 0x2) }
    }

    private fun sendToClient(connection: ClientConnection, data: ByteArray, opcode: Int) {
        executorService.execute {
            try {
                val output = connection.socket.getOutputStream()
                writeFrame(output, data, opcode)
            } catch (e: Exception) {
                Log.e(TAG, "Error sending message to ${connection.id}", e)
            }
        }
    }

    private fun writeFrame(output: OutputStream, data: ByteArray, opcode: Int) {
        val length = data.size
        
        // FIN + opcode
        output.write(0x80 or opcode)
        
        // Length
        when {
            length < 126 -> output.write(length)
            length < 65536 -> {
                output.write(126)
                output.write(length shr 8)
                output.write(length and 0xFF)
            }
            else -> {
                output.write(127)
                for (i in 7 downTo 0) {
                    output.write((length shr (8 * i)) and 0xFF)
                }
            }
        }
        
        // Payload (no mask for server-to-client)
        output.write(data)
        output.flush()
    }

    fun getConnectedClients(): List<String> = clients.keys.toList()

    // ========================================================================
    // Inner Classes
    // ========================================================================

    private class ClientConnection(
        val id: String,
        val socket: Socket
    ) {
        fun close() {
            try {
                socket.close()
            } catch (e: Exception) {
                // Ignore
            }
        }
    }

    interface WebSocketCallback {
        fun onServerStarted(port: Int)
        fun onServerStopped()
        fun onClientConnected(clientId: String)
        fun onClientDisconnected(clientId: String)
        fun onMessageReceived(clientId: String, message: String)
        fun onBinaryMessageReceived(clientId: String, data: ByteArray)
        fun onError(message: String)
    }
}
