package com.brimukon.messaging

import android.content.ContentValues
import android.content.Context
import android.net.Uri
import io.flutter.plugin.common.MethodChannel

class SmsRepository(private val context: Context) {

    fun writeOutgoingToSystemDb(
        address: String,
        body: String,
        date: Long,
        threadId: Long? = null
    ): Long? {
        val systemThreadId = getOrCreateSystemThreadId(address)

        val values = ContentValues().apply {
            put("address", address)
            put("body", body)
            put("date", date)
            put("type", 2)      // 2 = sent
            put("read", 1)
            put("seen", 1)
            if (systemThreadId != -1L) put("thread_id", systemThreadId)
        }
        return try {
            val uri = context.contentResolver.insert(
                Uri.parse("content://sms/sent"),
                values
            )
             uri?.lastPathSegment?.toLong()
        } catch (e: Exception) {
            null
        }
    }

    // Call this when message is received and you are default app
    fun writeIncomingToSystemDb(
        address: String,
        body: String,
        date: Long,
        threadId: Long? = null
    ): Long? {
        val values = ContentValues().apply {
            put("address", address)
            put("body", body)
            put("date", date)
            put("type", 1)      // 1 = inbox
            put("read", 0)
            put("seen", 0)
            if (threadId != null) put("thread_id", threadId)
        }
        return try {
            val uri = context.contentResolver.insert(
                Uri.parse("content://sms/inbox"),
                values
            )
            // Extract the ID from the end of the URI (e.g., content://sms/inbox/123)
            uri?.lastPathSegment?.toLong()
        } catch (e: Exception) {
            null
        }
    }
    fun getOrCreateSystemThreadId(address: String): Long {
    return try {
        // This is the official Android API — it queries or creates a thread
        // for the given address in the system telephony provider
        android.provider.Telephony.Threads.getOrCreateThreadId(context, address)
    } catch (e: Exception) {
        -1L
    }
}
}