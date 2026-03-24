package com.brimukon.messaging

import android.app.role.RoleManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.provider.Telephony
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    
    private val CHANNEL = "com.brimukon.messaging.defaultRole"
    private val smsRepo by lazy { SmsRepository(context) }
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "isDefaultSmsApp" -> {
                    result.success(isDefaultSmsApp())
                }
                "requestDefaultSmsRole" -> {
                    requestDefaultSmsRole()
                    result.success(true)
                }
                "writeOutgoingToSystemDb" -> {
                    val address = call.argument<String>("address") 
                        ?: return@setMethodCallHandler result.error("INVALID_ARGS", "address is required", null)
                    val body = call.argument<String>("body") 
                        ?: return@setMethodCallHandler result.error("INVALID_ARGS", "body is required", null)
                    val date = call.argument<Long>("date") ?: System.currentTimeMillis()
                    
                    val uri = smsRepo.writeOutgoingToSystemDb(address, body, date)
                    result.success(mapOf(
                        "uri" to uri?.toString()
                    ))
                }
                "writeIncomingToSystemDb" -> {
                    val address = call.argument<String>("address") 
                        ?: return@setMethodCallHandler result.error("INVALID_ARGS", "address is required", null)
                    val body = call.argument<String>("body") 
                        ?: return@setMethodCallHandler result.error("INVALID_ARGS", "body is required", null)
                    val date = call.argument<Long>("date") ?: System.currentTimeMillis()
                   
                    val uri = smsRepo.writeIncomingToSystemDb(address, body, date)
                    result.success(mapOf(
                        "uri" to uri?.toString()
                    ))
                }
                "getSystemThreadId" -> {
                    val address = call.argument<String>("address")
                        ?: return@setMethodCallHandler result.error("INVALID_ARGS", "address is required", null)
                    val threadId = smsRepo.getOrCreateSystemThreadId(address)
                    result.success(threadId)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun isDefaultSmsApp(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val roleManager = getSystemService(RoleManager::class.java)
            roleManager.isRoleHeld(RoleManager.ROLE_SMS)
        } else {
            Telephony.Sms.getDefaultSmsPackage(this) == packageName
        }
    }

    private fun requestDefaultSmsRole() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val roleManager = getSystemService(RoleManager::class.java)
            val intent = roleManager.createRequestRoleIntent(RoleManager.ROLE_SMS)
            startActivityForResult(intent, 123)
        } else {
            val intent = Intent(Telephony.Sms.Intents.ACTION_CHANGE_DEFAULT)
            intent.putExtra(Telephony.Sms.Intents.EXTRA_PACKAGE_NAME, packageName)
            startActivity(intent)
        }
    }
}