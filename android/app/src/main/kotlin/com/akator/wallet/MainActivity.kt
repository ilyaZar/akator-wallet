package com.akator.wallet

import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.akator.wallet/external_images"
        ).setMethodCallHandler { call, result ->
            if (call.method != "readExternalImage") {
                result.notImplemented()
                return@setMethodCallHandler
            }

            try {
                val uri = Uri.parse(requireNotNull(call.argument<String>("uri")))
                result.success(readBounded(uri))
            } catch (_: Exception) {
                result.error(
                    "legacy_image_unavailable",
                    "Could not read the legacy linked image",
                    null
                )
            }
        }
    }

    private fun readBounded(uri: Uri): ByteArray {
        return contentResolver.openInputStream(uri)?.use { input ->
            val output = ByteArrayOutputStream()
            val buffer = ByteArray(64 * 1024)
            var total = 0
            while (true) {
                val count = input.read(buffer)
                if (count < 0) {
                    break
                }
                total += count
                require(total <= MaxLegacyImageBytes)
                output.write(buffer, 0, count)
            }
            output.toByteArray()
        } ?: error("Image unavailable")
    }

    companion object {
        private const val MaxLegacyImageBytes = 12 * 1024 * 1024
    }
}
