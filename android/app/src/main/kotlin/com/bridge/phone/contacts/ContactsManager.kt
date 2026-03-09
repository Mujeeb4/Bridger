package com.bridge.phone.contacts

import android.content.Context
import android.provider.ContactsContract
import android.util.Base64
import org.json.JSONArray
import org.json.JSONObject
import java.io.ByteArrayOutputStream

/**
 * Manager for reading device contacts
 */
class ContactsManager(private val context: Context) {

    /**
     * Get all contacts from the device
     * Returns a list of maps with contact data
     */
    fun getContacts(): List<Map<String, Any?>> {
        val contacts = mutableListOf<Map<String, Any?>>()
        val processedNumbers = mutableSetOf<String>()
        
        val cursor = context.contentResolver.query(
            ContactsContract.CommonDataKinds.Phone.CONTENT_URI,
            arrayOf(
                ContactsContract.CommonDataKinds.Phone.CONTACT_ID,
                ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME,
                ContactsContract.CommonDataKinds.Phone.NUMBER,
                ContactsContract.CommonDataKinds.Phone.PHOTO_URI
            ),
            null,
            null,
            ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME + " ASC"
        )
        
        cursor?.use {
            val idIndex = it.getColumnIndex(ContactsContract.CommonDataKinds.Phone.CONTACT_ID)
            val nameIndex = it.getColumnIndex(ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME)
            val numberIndex = it.getColumnIndex(ContactsContract.CommonDataKinds.Phone.NUMBER)
            val photoIndex = it.getColumnIndex(ContactsContract.CommonDataKinds.Phone.PHOTO_URI)
            
            while (it.moveToNext()) {
                val contactId = if (idIndex >= 0) it.getLong(idIndex) else 0L
                val name = if (nameIndex >= 0) it.getString(nameIndex) else null
                val number = if (numberIndex >= 0) it.getString(numberIndex) else null
                val photoUri = if (photoIndex >= 0) it.getString(photoIndex) else null
                
                // Normalize phone number for deduplication
                val normalizedNumber = normalizePhoneNumber(number)
                
                if (normalizedNumber != null && !processedNumbers.contains(normalizedNumber)) {
                    processedNumbers.add(normalizedNumber)
                    
                    contacts.add(mapOf(
                        "id" to contactId,
                        "name" to (name ?: "Unknown"),
                        "phoneNumber" to normalizedNumber,
                        "photoUrl" to photoUri
                    ))
                }
            }
        }
        
        return contacts
    }
    
    /**
     * Get contact count
     */
    fun getContactCount(): Int {
        val cursor = context.contentResolver.query(
            ContactsContract.Contacts.CONTENT_URI,
            arrayOf(ContactsContract.Contacts._ID),
            ContactsContract.Contacts.HAS_PHONE_NUMBER + " = 1",
            null,
            null
        )
        
        val count = cursor?.count ?: 0
        cursor?.close()
        return count
    }
    
    /**
     * Get contact by phone number
     */
    fun getContactByPhoneNumber(phoneNumber: String): Map<String, Any?>? {
        val normalizedInput = normalizePhoneNumber(phoneNumber) ?: return null
        
        val cursor = context.contentResolver.query(
            ContactsContract.CommonDataKinds.Phone.CONTENT_URI,
            arrayOf(
                ContactsContract.CommonDataKinds.Phone.CONTACT_ID,
                ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME,
                ContactsContract.CommonDataKinds.Phone.NUMBER,
                ContactsContract.CommonDataKinds.Phone.PHOTO_URI
            ),
            null,
            null,
            null
        )
        
        cursor?.use {
            val nameIndex = it.getColumnIndex(ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME)
            val numberIndex = it.getColumnIndex(ContactsContract.CommonDataKinds.Phone.NUMBER)
            val photoIndex = it.getColumnIndex(ContactsContract.CommonDataKinds.Phone.PHOTO_URI)
            val idIndex = it.getColumnIndex(ContactsContract.CommonDataKinds.Phone.CONTACT_ID)
            
            while (it.moveToNext()) {
                val number = if (numberIndex >= 0) it.getString(numberIndex) else null
                val normalized = normalizePhoneNumber(number)
                
                if (normalized != null && (normalized == normalizedInput || 
                    normalized.endsWith(normalizedInput) || 
                    normalizedInput.endsWith(normalized))) {
                    
                    return mapOf(
                        "id" to (if (idIndex >= 0) it.getLong(idIndex) else 0L),
                        "name" to (if (nameIndex >= 0) it.getString(nameIndex) else "Unknown"),
                        "phoneNumber" to normalized,
                        "photoUrl" to (if (photoIndex >= 0) it.getString(photoIndex) else null)
                    )
                }
            }
        }
        
        return null
    }
    
    /**
     * Get contact photo as base64 (for syncing to iPhone)
     */
    fun getContactPhotoBase64(contactId: Long): String? {
        val uri = ContactsContract.Contacts.CONTENT_URI.buildUpon()
            .appendPath(contactId.toString())
            .build()
        
        val cursor = context.contentResolver.query(
            uri,
            arrayOf(ContactsContract.Contacts.PHOTO_URI),
            null,
            null,
            null
        )
        
        cursor?.use {
            if (it.moveToFirst()) {
                val photoUri = it.getString(0)
                if (photoUri != null) {
                    try {
                        val inputStream = context.contentResolver.openInputStream(
                            android.net.Uri.parse(photoUri)
                        )
                        inputStream?.use { stream ->
                            val outputStream = ByteArrayOutputStream()
                            val buffer = ByteArray(4096)
                            var bytesRead: Int
                            while (stream.read(buffer).also { bytesRead = it } != -1) {
                                outputStream.write(buffer, 0, bytesRead)
                            }
                            return Base64.encodeToString(
                                outputStream.toByteArray(), 
                                Base64.NO_WRAP
                            )
                        }
                    } catch (e: Exception) {
                        // Photo not accessible
                    }
                }
            }
        }
        
        return null
    }
    
    /**
     * Normalize phone number for comparison
     */
    private fun normalizePhoneNumber(number: String?): String? {
        if (number.isNullOrBlank()) return null
        
        // Remove all non-digit characters except leading +
        val cleaned = number.trim()
        val hasPlus = cleaned.startsWith("+")
        val digits = cleaned.replace(Regex("[^0-9]"), "")
        
        return if (digits.isEmpty()) null 
               else if (hasPlus) "+$digits" 
               else digits
    }
}
