package com.bridge.phone.crypto

import android.content.Context
import android.content.SharedPreferences
import android.util.Base64
import android.util.Log
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey
import java.security.SecureRandom
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec
import javax.crypto.spec.SecretKeySpec

/**
 * Manages encryption keys and operations using hardware-backed security
 */
class EncryptionManager(context: Context) {

    companion object {
        private const val TAG = "EncryptionManager"
        private const val PREFS_FILENAME = "bridge_secure_prefs"
        private const val KEY_PAIRING_CODE = "pairing_code"
        private const val KEY_SHARED_SECRET = "shared_secret" // Stored as Base64
        private const val AES_KEY_SIZE = 256
        private const val GCM_TAG_LENGTH = 128
        private const val GCM_IV_LENGTH = 12
    }

    private val securePrefs: SharedPreferences

    init {
        val masterKey = MasterKey.Builder(context)
            .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
            .build()

        securePrefs = EncryptedSharedPreferences.create(
            context,
            PREFS_FILENAME,
            masterKey,
            EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
            EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM
        )
    }

    /**
     * Store the temporary pairing code
     */
    fun setPairingCode(code: String) {
        securePrefs.edit().putString(KEY_PAIRING_CODE, code).apply()
        Log.d(TAG, "Pairing code stored securely")
    }

    /**
     * Validate a received pairing code
     */
    fun validatePairingCode(code: String): Boolean {
        val storedCode = securePrefs.getString(KEY_PAIRING_CODE, null)
        if (storedCode == null) {
            Log.w(TAG, "No pairing code stored")
            return false
        }
        return storedCode == code
    }

    /**
     * Clear pairing code (after successful pairing or timeout)
     */
    fun clearPairingCode() {
        securePrefs.edit().remove(KEY_PAIRING_CODE).apply()
    }

    /**
     * Generate a new AES-256 key and store it
     * Returns Base64 encoded key bytes
     */
    fun generateAndStoreKey(): String {
        val keyGen = KeyGenerator.getInstance("AES")
        keyGen.init(AES_KEY_SIZE)
        val secretKey = keyGen.generateKey()
        val keyBytes = secretKey.encoded
        val keyBase64 = Base64.encodeToString(keyBytes, Base64.NO_WRAP)

        securePrefs.edit().putString(KEY_SHARED_SECRET, keyBase64).apply()
        Log.d(TAG, "New shared key generated and stored")
        return keyBase64
    }

    /**
     * Get the stored shared key (Base64 encoded)
     */
    fun getSharedKey(): String? {
        return securePrefs.getString(KEY_SHARED_SECRET, null)
    }

    /**
     * Encrypt data using the stored shared key (AES-GCM)
     * Output format: Base64(IV + CipherText + AuthTag)
     */
    fun encrypt(plaintext: ByteArray): String {
        val keyBase64 = getSharedKey() ?: throw IllegalStateException("No shared key found")
        val keyBytes = Base64.decode(keyBase64, Base64.NO_WRAP)
        val key = SecretKeySpec(keyBytes, "AES")

        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        val iv = ByteArray(GCM_IV_LENGTH)
        SecureRandom().nextBytes(iv)
        val spec = GCMParameterSpec(GCM_TAG_LENGTH, iv)
        cipher.init(Cipher.ENCRYPT_MODE, key, spec)

        val cipherText = cipher.doFinal(plaintext)
        
        // Combine IV + CipherText
        val combined = ByteArray(iv.size + cipherText.size)
        System.arraycopy(iv, 0, combined, 0, iv.size)
        System.arraycopy(cipherText, 0, combined, iv.size, cipherText.size)

        return Base64.encodeToString(combined, Base64.NO_WRAP)
    }

    /**
     * Decrypt data using the stored shared key (AES-GCM)
     * Input: Base64(IV + CipherText + AuthTag)
     */
    fun decrypt(encryptedBase64: String): ByteArray {
        val keyBase64 = getSharedKey() ?: throw IllegalStateException("No shared key found")
        val keyBytes = Base64.decode(keyBase64, Base64.NO_WRAP)
        val key = SecretKeySpec(keyBytes, "AES")

        val combined = Base64.decode(encryptedBase64, Base64.NO_WRAP)
        
        if (combined.size < GCM_IV_LENGTH) throw IllegalArgumentException("Invalid encrypted data")

        val iv = ByteArray(GCM_IV_LENGTH)
        System.arraycopy(combined, 0, iv, 0, GCM_IV_LENGTH)
        
        val cipherTextSize = combined.size - GCM_IV_LENGTH
        val cipherText = ByteArray(cipherTextSize)
        System.arraycopy(combined, GCM_IV_LENGTH, cipherText, 0, cipherTextSize)

        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        val spec = GCMParameterSpec(GCM_TAG_LENGTH, iv)
        cipher.init(Cipher.DECRYPT_MODE, key, spec)

        return cipher.doFinal(cipherText)
    }
}
