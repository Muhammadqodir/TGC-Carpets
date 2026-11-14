package uz.mq.tgc

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

/**
 * Hosts the Flutter UI and, on Zebra PDAs (TC15 and friends), bridges the
 * built-in imager to Dart.
 *
 * DataWedge, Zebra's scanning service, is told to give this app its own
 * profile: the trigger button reads Code 128 / Data Matrix / QR / EAN-13 and
 * hands the text over as a broadcast instead of typing it as keystrokes, so a
 * scan can never land in whatever text field happens to have focus. Dart
 * listens on [SCAN_EVENTS]; the receiver is registered only while someone
 * listens, so a scan on a page that has no use for it is simply dropped.
 */
class MainActivity : FlutterActivity() {
    companion object {
        private const val SCANNER_METHODS = "uz.mq.tgc/scanner"
        private const val SCAN_EVENTS = "uz.mq.tgc/scanner/events"

        private const val DATAWEDGE_PACKAGE = "com.symbol.datawedge"
        private const val DW_ACTION = "com.symbol.datawedge.api.ACTION"
        private const val DW_PROFILE = "TGC"

        /** What DataWedge broadcasts each decoded barcode as. */
        private const val SCAN_ACTION = "uz.mq.tgc.SCAN"
        private const val EXTRA_DATA = "com.symbol.datawedge.data_string"
        private const val EXTRA_LABEL_TYPE = "com.symbol.datawedge.label_type"
    }

    private var scanReceiver: BroadcastReceiver? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger

        if (hasDataWedge()) configureDataWedge()

        MethodChannel(messenger, SCANNER_METHODS).setMethodCallHandler { call, result ->
            when (call.method) {
                "isAvailable" -> result.success(hasDataWedge())
                "softTrigger" -> {
                    // Same as pressing the yellow button: fires the imager.
                    if (hasDataWedge()) {
                        sendBroadcast(Intent(DW_ACTION).apply {
                            putExtra("com.symbol.datawedge.api.SOFT_SCAN_TRIGGER", "TOGGLE_SCANNING")
                        })
                    }
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        EventChannel(messenger, SCAN_EVENTS).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                unregisterScanReceiver()
                val receiver = object : BroadcastReceiver() {
                    override fun onReceive(context: Context, intent: Intent) {
                        val data = intent.getStringExtra(EXTRA_DATA) ?: return
                        events.success(
                            mapOf(
                                "data" to data,
                                "type" to intent.getStringExtra(EXTRA_LABEL_TYPE),
                            )
                        )
                    }
                }
                val filter = IntentFilter(SCAN_ACTION).apply {
                    addCategory(Intent.CATEGORY_DEFAULT)
                }
                // DataWedge is another app, so the receiver must be exported.
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    registerReceiver(receiver, filter, Context.RECEIVER_EXPORTED)
                } else {
                    @Suppress("UnspecifiedRegisterReceiverFlag")
                    registerReceiver(receiver, filter)
                }
                scanReceiver = receiver
            }

            override fun onCancel(arguments: Any?) {
                unregisterScanReceiver()
            }
        })
    }

    override fun onDestroy() {
        unregisterScanReceiver()
        super.onDestroy()
    }

    private fun unregisterScanReceiver() {
        scanReceiver?.let {
            try {
                unregisterReceiver(it)
            } catch (_: IllegalArgumentException) {
                // Already gone.
            }
        }
        scanReceiver = null
    }

    private fun hasDataWedge(): Boolean = try {
        packageManager.getPackageInfo(DATAWEDGE_PACKAGE, 0)
        true
    } catch (_: PackageManager.NameNotFoundException) {
        false
    }

    /**
     * Creates (or refreshes) the app's DataWedge profile. Sent on every start,
     * so a profile someone edited by hand on the device is put back the way
     * the app needs it.
     */
    private fun configureDataWedge() {
        val barcode = Bundle().apply {
            putString("PLUGIN_NAME", "BARCODE")
            putString("RESET_CONFIG", "true")
            putBundle("PARAM_LIST", Bundle().apply {
                putString("scanner_selection", "auto")
                putString("scanner_input_enabled", "true")
                putString("decoder_code128", "true")
                putString("decoder_datamatrix", "true")
                putString("decoder_qrcode", "true")
                putString("decoder_ean13", "true")
            })
        }
        val intentOutput = Bundle().apply {
            putString("PLUGIN_NAME", "INTENT")
            putString("RESET_CONFIG", "true")
            putBundle("PARAM_LIST", Bundle().apply {
                putString("intent_output_enabled", "true")
                putString("intent_action", SCAN_ACTION)
                putString("intent_category", Intent.CATEGORY_DEFAULT)
                putString("intent_delivery", "2") // broadcast
            })
        }
        val keystroke = Bundle().apply {
            putString("PLUGIN_NAME", "KEYSTROKE")
            putString("RESET_CONFIG", "true")
            putBundle("PARAM_LIST", Bundle().apply {
                putString("keystroke_output_enabled", "false")
            })
        }
        val config = Bundle().apply {
            putString("PROFILE_NAME", DW_PROFILE)
            putString("PROFILE_ENABLED", "true")
            putString("CONFIG_MODE", "CREATE_IF_NOT_EXIST")
            putParcelableArrayList("PLUGIN_CONFIG", arrayListOf(barcode, intentOutput, keystroke))
            putParcelableArray("APP_LIST", arrayOf(Bundle().apply {
                putString("PACKAGE_NAME", packageName)
                putStringArray("ACTIVITY_LIST", arrayOf("*"))
            }))
        }

        sendBroadcast(Intent(DW_ACTION).apply {
            putExtra("com.symbol.datawedge.api.SET_CONFIG", config)
        })
    }
}
