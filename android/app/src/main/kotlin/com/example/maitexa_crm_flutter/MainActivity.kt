package com.example.maitexa_crm_flutter

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import android.telephony.SubscriptionInfo
import android.telephony.SubscriptionManager
import android.telephony.TelephonyManager
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.maitexa.crm/sim_info"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getSimPhoneNumbers" -> {
                    result.success(getSimPhoneNumbers())
                }
                else -> result.notImplemented()
            }
        }
    }

    /**
     * Returns a list of maps, each containing:
     *   - "subscriptionId" (Int)
     *   - "slotIndex" (Int)
     *   - "phoneNumber" (String, may be empty on some devices/carriers)
     *   - "displayName" (String)
     *   - "iccId" (String)
     *
     * On Android 14+ READ_PHONE_NUMBERS is the required permission for getLine1Number.
     * On older versions READ_PHONE_STATE suffices.
     */
    private fun getSimPhoneNumbers(): List<Map<String, Any?>> {
        val simList = mutableListOf<Map<String, Any?>>()

        // Check that we have at least READ_PHONE_STATE
        val hasPhoneState = ContextCompat.checkSelfPermission(
            this, Manifest.permission.READ_PHONE_STATE
        ) == PackageManager.PERMISSION_GRANTED

        val hasPhoneNumbers = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            ContextCompat.checkSelfPermission(
                this, Manifest.permission.READ_PHONE_NUMBERS
            ) == PackageManager.PERMISSION_GRANTED
        } else {
            hasPhoneState // on < API 30 READ_PHONE_STATE covers it
        }

        if (!hasPhoneState && !hasPhoneNumbers) {
            return simList
        }

        try {
            val subscriptionManager = getSystemService(TELEPHONY_SUBSCRIPTION_SERVICE) as? SubscriptionManager
                ?: return simList

            val activeSubscriptions: List<SubscriptionInfo>? =
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP_MR1) {
                    if (hasPhoneState) {
                        subscriptionManager.activeSubscriptionInfoList
                    } else null
                } else null

            if (activeSubscriptions != null) {
                for (info in activeSubscriptions) {
                    val phoneNumber = tryGetPhoneNumber(info, hasPhoneNumbers)
                    simList.add(
                        mapOf(
                            "subscriptionId" to info.subscriptionId,
                            "slotIndex" to info.simSlotIndex,
                            "phoneNumber" to (phoneNumber ?: ""),
                            "displayName" to (info.displayName?.toString() ?: "SIM ${info.simSlotIndex + 1}"),
                            "iccId" to (info.iccId ?: ""),
                        )
                    )
                }
            }
        } catch (e: Exception) {
            // Permissions denied or device doesn't support subscription info
        }

        return simList
    }

    private fun tryGetPhoneNumber(info: SubscriptionInfo, hasPhoneNumbers: Boolean): String? {
        if (!hasPhoneNumbers) return null
        return try {
            val telephonyManager = getSystemService(TELEPHONY_SERVICE) as? TelephonyManager
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP_MR1) {
                val simTelephony = telephonyManager?.createForSubscriptionId(info.subscriptionId)
                val line1 = simTelephony?.line1Number
                if (!line1.isNullOrBlank()) line1 else null
            } else {
                val line1 = telephonyManager?.line1Number
                if (!line1.isNullOrBlank()) line1 else null
            }
        } catch (e: Exception) {
            null
        }
    }
}
