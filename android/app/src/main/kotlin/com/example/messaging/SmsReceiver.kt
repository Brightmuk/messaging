package com.brimukon.messaging

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class SmsReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context?, intent: Intent?) {
        // You can leave this empty. 
        // The 'telephony' library's receiver will handle the heavy lifting.
    }
}