package com.brimukon.messaging

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.provider.Telephony

class SmsReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context?, intent: Intent?) {
        if (context == null || intent == null) return
        if (intent.action != Telephony.Sms.Intents.SMS_DELIVER_ACTION) return

        val messages = Telephony.Sms.Intents.getMessagesFromIntent(intent)
        if (messages.isNullOrEmpty()) return

        val address = messages[0].originatingAddress ?: return
        // Reconstruct full body — multipart SMS arrives as fragments
        val body = messages.joinToString("") { it.messageBody }
        val date = System.currentTimeMillis()

        SmsRepository(context).writeIncomingToSystemDb(address, body, date)
    }
}