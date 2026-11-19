package com.example.expenso

import android.Manifest
import android.app.Activity
import android.content.pm.PackageManager
import android.net.Uri
import android.provider.Telephony
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry

/**
 * Reads the SMS inbox so Expenso can offer bank messages as draft entries.
 *
 * Deliberately minimal: it returns raw message text and lets Dart do all the
 * interpreting, so the parsing logic stays testable on any machine rather than
 * being locked behind a device.
 *
 * Nothing is read until the person turns the feature on and grants the
 * permission, and nothing ever leaves the phone.
 */
class SmsReader(private val activity: Activity) :
    MethodChannel.MethodCallHandler, PluginRegistry.RequestPermissionsResultListener {

    companion object {
        const val CHANNEL = "expenso/sms"
        private const val REQUEST_CODE = 7301
    }

    private var pendingPermission: MethodChannel.Result? = null

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "hasPermission" -> result.success(hasPermission())
            "requestPermission" -> requestPermission(result)
            "readInbox" -> readInbox(call, result)
            else -> result.notImplemented()
        }
    }

    private fun hasPermission(): Boolean =
        ContextCompat.checkSelfPermission(activity, Manifest.permission.READ_SMS) ==
            PackageManager.PERMISSION_GRANTED

    private fun requestPermission(result: MethodChannel.Result) {
        if (hasPermission()) {
            result.success(true)
            return
        }
        // Only one prompt can be in flight; a second request while one is open
        // would otherwise strand the first result and hang the Dart side.
        if (pendingPermission != null) {
            result.success(false)
            return
        }
        pendingPermission = result
        ActivityCompat.requestPermissions(
            activity,
            arrayOf(Manifest.permission.READ_SMS),
            REQUEST_CODE,
        )
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ): Boolean {
        if (requestCode != REQUEST_CODE) return false
        val granted = grantResults.isNotEmpty() &&
            grantResults[0] == PackageManager.PERMISSION_GRANTED
        pendingPermission?.success(granted)
        pendingPermission = null
        return true
    }

    private fun readInbox(call: MethodCall, result: MethodChannel.Result) {
        if (!hasPermission()) {
            result.error("no_permission", "READ_SMS has not been granted", null)
            return
        }

        val since = call.argument<Long>("sinceMillis") ?: 0L
        val limit = call.argument<Int>("limit") ?: 200

        val messages = ArrayList<Map<String, Any?>>()
        try {
            val cursor = activity.contentResolver.query(
                Uri.parse("content://sms/inbox"),
                arrayOf(
                    Telephony.Sms._ID,
                    Telephony.Sms.ADDRESS,
                    Telephony.Sms.BODY,
                    Telephony.Sms.DATE,
                ),
                "${Telephony.Sms.DATE} > ?",
                arrayOf(since.toString()),
                "${Telephony.Sms.DATE} DESC LIMIT $limit",
            )

            cursor?.use {
                val idColumn = it.getColumnIndexOrThrow(Telephony.Sms._ID)
                val addressColumn = it.getColumnIndexOrThrow(Telephony.Sms.ADDRESS)
                val bodyColumn = it.getColumnIndexOrThrow(Telephony.Sms.BODY)
                val dateColumn = it.getColumnIndexOrThrow(Telephony.Sms.DATE)

                while (it.moveToNext()) {
                    messages.add(
                        mapOf(
                            "id" to it.getString(idColumn),
                            "sender" to it.getString(addressColumn),
                            "body" to it.getString(bodyColumn),
                            "receivedAt" to it.getLong(dateColumn),
                        )
                    )
                }
            }
            result.success(messages)
        } catch (error: Exception) {
            result.error("read_failed", error.message, null)
        }
    }
}
