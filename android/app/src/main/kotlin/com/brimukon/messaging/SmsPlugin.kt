package com.brimukon.messaging

import android.app.Activity
import android.app.role.RoleManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.provider.Telephony
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler

class SmsPlugin : FlutterPlugin, MethodCallHandler, ActivityAware {
    private lateinit var channel: MethodChannel
    private lateinit var context: Context
    private var activity: Activity? = null
    private val smsRepo by lazy { SmsRepository(context) }
    private val CHANNEL_NAME = "com.brimukon.messaging.defaultRole"

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, CHANNEL_NAME)
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isDefaultSmsApp" -> result.success(isDefaultSmsApp())
            "requestDefaultSmsRole" -> {
                requestDefaultSmsRole()
                result.success(true)
            }
            "writeOutgoingToSystemDb" -> {
                val address = call.argument<String>("address") ?: return result.error("ERR", "No address", null)
                val body = call.argument<String>("body") ?: return result.error("ERR", "No body", null)
                val date = call.argument<Long>("date") ?: System.currentTimeMillis()
                val newSystemId = smsRepo.writeOutgoingToSystemDb(address, body, date)
                result.success(newSystemId)
            }
            "writeIncomingToSystemDb" -> {
                val address = call.argument<String>("address") ?: return result.error("ERR", "No address", null)
                val body = call.argument<String>("body") ?: return result.error("ERR", "No body", null)
                val date = call.argument<Long>("date") ?: System.currentTimeMillis()
                val newSystemId = smsRepo.writeIncomingToSystemDb(address, body, date)
                result.success(newSystemId)
            }
            "getSystemThreadId" -> {
                val address = call.argument<String>("address") ?: return result.error("ERR", "No address", null)
                result.success(smsRepo.getOrCreateSystemThreadId(address))
            }
            else -> result.notImplemented()
        }
    }

    private fun isDefaultSmsApp(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val roleManager = context.getSystemService(RoleManager::class.java)
            roleManager.isRoleHeld(RoleManager.ROLE_SMS)
        } else {
            Telephony.Sms.getDefaultSmsPackage(context) == context.packageName
        }
    }

    private fun requestDefaultSmsRole() {
        val currentActivity = activity ?: return 
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val roleManager = currentActivity.getSystemService(RoleManager::class.java)
            val intent = roleManager.createRequestRoleIntent(RoleManager.ROLE_SMS)
            currentActivity.startActivityForResult(intent, 123)
        } else {
            val intent = Intent(Telephony.Sms.Intents.ACTION_CHANGE_DEFAULT)
            intent.putExtra(Telephony.Sms.Intents.EXTRA_PACKAGE_NAME, currentActivity.packageName)
            currentActivity.startActivity(intent)
        }
    }

    // Boilerplate for ActivityAware (required for the "Request Role" dialog)
    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) { channel.setMethodCallHandler(null) }
    override fun onAttachedToActivity(binding: ActivityPluginBinding) { activity = binding.activity }
    override fun onDetachedFromActivityForConfigChanges() { activity = null }
    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) { activity = binding.activity }
    override fun onDetachedFromActivity() { activity = null }
}