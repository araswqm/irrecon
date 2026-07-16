package com.irrecon

import android.content.Context
import android.hardware.ConsumerIrManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val channel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        )

        channel.setMethodCallHandler { call, result ->
            val irManager =
                getSystemService(Context.CONSUMER_IR_SERVICE) as ConsumerIrManager

            when (call.method) {
                "isAvailable" -> {
                    result.success(irManager.hasIrEmitter())
                }

                "transmit" -> {
                    if (!irManager.hasIrEmitter()) {
                        result.error(
                            "NO_IR_EMITTER",
                            "Device does not have an IR emitter",
                            null
                        )
                        return@setMethodCallHandler
                    }

                    val frequency = call.argument<Int>("frequency") ?: 38000
                    val pattern = call.argument<List<Int>>("pattern")

                    if (pattern == null || pattern.isEmpty()) {
                        result.error(
                            "INVALID_PATTERN",
                            "Pattern is null or empty",
                            null
                        )
                        return@setMethodCallHandler
                    }

                    // ConsumerIrManager.transmit requires int[] (primitive array)
                    val intArray = IntArray(pattern.size) { i ->
                        // Clamp to positive values
                        maxOf(0, pattern[i])
                    }

                    irManager.transmit(frequency, intArray)
                    result.success(true)
                }

                else -> result.notImplemented()
            }
        }
    }

    companion object {
        private const val CHANNEL = "com.irrecon/ir"
    }
}
