package com.akator.wallet

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.provider.DocumentsContract
import android.provider.OpenableColumns
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private var pendingResult: MethodChannel.Result? = null
    private var pendingArgs: Map<*, *>? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.akator.wallet/external_images"
        ).setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "isExternalProviderAvailable" -> isExternalProviderAvailable(call, result)
                    "pickSyncthingFolder" -> pickSyncthingFolder(result)
                    "openProviderFiles" -> openProviderFiles(call, result)
                    "openProviderApp" -> openProviderApp(call, result)
                    "pickExternalImage" -> pickExternalImage(call, result)
                    "cacheExternalImage" -> cacheExternalImage(call, result)
                    "saveCroppedExternalImage" -> saveCroppedExternalImage(call, result)
                    "readExternalImage" -> readExternalImage(call, result)
                    else -> result.notImplemented()
                }
            } catch (error: Exception) {
                result.error("external_storage_error", error.message, null)
            }
        }
    }

    private fun isExternalProviderAvailable(call: MethodCall, result: MethodChannel.Result) {
        val provider = call.argument<String>("provider")
        result.success(providerPackage(provider) != null || provider == "internal")
    }

    private fun pickSyncthingFolder(result: MethodChannel.Result) {
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE)
            .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            .addFlags(Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
            .addFlags(Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION)
            .addFlags(Intent.FLAG_GRANT_PREFIX_URI_PERMISSION)
            .putExtra("android.content.extra.SHOW_ADVANCED", true)

        launchPending(intent, RequestTree, null, result)
    }

    private fun openProviderFiles(call: MethodCall, result: MethodChannel.Result) {
        val initialUri = call.argument<String>("initialUri")?.let(Uri::parse)
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT)
            .addCategory(Intent.CATEGORY_OPENABLE)
            .setType("*/*")
            .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            .addFlags(Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION)
            .putExtra("android.content.extra.SHOW_ADVANCED", true)

        if (initialUri != null) {
            intent.putExtra("android.provider.extra.INITIAL_URI", initialUri)
        }

        result.success(startExternalActivity(intent))
    }

    private fun openProviderApp(call: MethodCall, result: MethodChannel.Result) {
        val provider = call.argument<String>("provider")
        val packageName = providerPackage(provider)
        val intent = packageName?.let(packageManager::getLaunchIntentForPackage)

        result.success(intent?.let(::startExternalActivity) ?: false)
    }

    private fun pickExternalImage(call: MethodCall, result: MethodChannel.Result) {
        val initialUri = call.argument<String>("initialUri")?.let(Uri::parse)
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT)
            .addCategory(Intent.CATEGORY_OPENABLE)
            .setType("image/*")
            .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            .addFlags(Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION)
            .putExtra("android.content.extra.SHOW_ADVANCED", true)

        if (initialUri != null) {
            intent.putExtra("android.provider.extra.INITIAL_URI", initialUri)
        }

        launchPending(intent, RequestOpenImage, null, result)
    }

    private fun cacheExternalImage(call: MethodCall, result: MethodChannel.Result) {
        val uri = Uri.parse(requireNotNull(call.argument<String>("uri")))
        val displayName = cleanFileName(call.argument<String>("displayName") ?: "card-image.jpg")
        val cacheDirectory = File(cacheDir, "external_images").apply { mkdirs() }
        val cacheFile = File(cacheDirectory, "${System.currentTimeMillis()}_$displayName")

        contentResolver.openInputStream(uri)?.use { input ->
            cacheFile.outputStream().use { output -> input.copyTo(output) }
        } ?: error("Could not read selected image")

        result.success(cacheFile.absolutePath)
    }

    private fun saveCroppedExternalImage(call: MethodCall, result: MethodChannel.Result) {
        val args = call.arguments as? Map<*, *> ?: emptyMap<String, Any?>()
        val provider = args["provider"] as? String
        val folderUri = (args["folderUri"] as? String)?.let(Uri::parse)
        val filePath = requireNotNull(args["filePath"] as? String)
        val displayName = cleanFileName((args["displayName"] as? String) ?: "card-image-cropped.jpg")
        val mimeType = (args["mimeType"] as? String)?.takeIf { it.startsWith("image/") } ?: "image/jpeg"

        if (provider == "syncthing" && folderUri != null) {
            val uri = createImageInTree(folderUri, filePath, displayName, mimeType)
            result.success(uri?.let { imageResult(it, displayName, mimeType) })
            return
        }

        val intent = Intent(Intent.ACTION_CREATE_DOCUMENT)
            .addCategory(Intent.CATEGORY_OPENABLE)
            .setType(mimeType)
            .putExtra(Intent.EXTRA_TITLE, displayName)
            .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            .addFlags(Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
            .addFlags(Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION)

        launchPending(
            intent,
            RequestCreateImage,
            mapOf("filePath" to filePath, "displayName" to displayName, "mimeType" to mimeType),
            result
        )
    }

    private fun readExternalImage(call: MethodCall, result: MethodChannel.Result) {
        val uri = Uri.parse(requireNotNull(call.argument<String>("uri")))
        val bytes = contentResolver.openInputStream(uri)?.use { it.readBytes() }
            ?: error("Could not read linked image")
        result.success(bytes)
    }

    private fun launchPending(
        intent: Intent,
        requestCode: Int,
        args: Map<*, *>?,
        result: MethodChannel.Result,
    ) {
        if (pendingResult != null) {
            result.error("external_storage_busy", "Another storage picker is already open", null)
            return
        }

        pendingResult = result
        pendingArgs = args
        startActivityForResult(intent, requestCode)
    }

    private fun startExternalActivity(intent: Intent): Boolean {
        return try {
            startActivity(intent)
            true
        } catch (_: ActivityNotFoundException) {
            false
        }
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)

        val result = pendingResult ?: return
        val args = pendingArgs
        pendingResult = null
        pendingArgs = null

        if (resultCode != Activity.RESULT_OK || data?.data == null) {
            result.success(null)
            return
        }

        val uri = data.data!!
        try {
            when (requestCode) {
                RequestTree -> {
                    persistUriPermission(uri, data.flags, true)
                    result.success(uri.toString())
                }

                RequestOpenImage -> {
                    persistUriPermission(uri, data.flags, false)
                    result.success(imageResult(uri))
                }

                RequestCreateImage -> {
                    val createArgs = requireNotNull(args)
                    val filePath = requireNotNull(createArgs["filePath"] as? String)
                    val displayName = requireNotNull(createArgs["displayName"] as? String)
                    val mimeType = requireNotNull(createArgs["mimeType"] as? String)
                    writeFileToUri(filePath, uri)
                    persistUriPermission(uri, data.flags, true)
                    result.success(imageResult(uri, displayName, mimeType))
                }

                else -> result.success(null)
            }
        } catch (error: Exception) {
            result.error("external_storage_error", error.message, null)
        }
    }

    private fun persistUriPermission(uri: Uri, flags: Int, write: Boolean) {
        val mask = Intent.FLAG_GRANT_READ_URI_PERMISSION or
            if (write) Intent.FLAG_GRANT_WRITE_URI_PERMISSION else 0
        val grantedFlags = flags and mask
        if (grantedFlags != 0) {
            contentResolver.takePersistableUriPermission(uri, grantedFlags)
        }
    }

    private fun createImageInTree(
        treeUri: Uri,
        filePath: String,
        displayName: String,
        mimeType: String,
    ): Uri? {
        val documentUri = DocumentsContract.buildDocumentUriUsingTree(
            treeUri,
            DocumentsContract.getTreeDocumentId(treeUri)
        )
        val targetUri = DocumentsContract.createDocument(
            contentResolver,
            documentUri,
            mimeType,
            displayName
        ) ?: return null

        writeFileToUri(filePath, targetUri)
        return targetUri
    }

    private fun writeFileToUri(filePath: String, uri: Uri) {
        File(filePath).inputStream().use { input ->
            contentResolver.openOutputStream(uri, "wt")?.use { output ->
                input.copyTo(output)
            } ?: error("Could not write cropped image")
        }
    }

    private fun imageResult(
        uri: Uri,
        displayName: String? = null,
        mimeType: String? = null,
    ): Map<String, String> {
        val metadata = imageMetadata(uri)
        return mapOf(
            "uri" to uri.toString(),
            "displayName" to (displayName ?: metadata.first),
            "mimeType" to (mimeType ?: metadata.second)
        )
    }

    private fun imageMetadata(uri: Uri): Pair<String, String> {
        var displayName = uri.lastPathSegment ?: "card-image.jpg"
        contentResolver.query(uri, null, null, null, null)?.use { cursor ->
            val nameIndex = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
            if (nameIndex >= 0 && cursor.moveToFirst()) {
                displayName = cursor.getString(nameIndex)
            }
        }

        return displayName to (contentResolver.getType(uri) ?: "image/*")
    }

    private fun cleanFileName(value: String): String {
        return value.replace(Regex("[^A-Za-z0-9._-]"), "_")
            .ifBlank { "card-image.jpg" }
    }

    private fun isPackageInstalled(packageName: String): Boolean {
        return try {
            packageManager.getPackageInfo(packageName, 0)
            true
        } catch (_: PackageManager.NameNotFoundException) {
            false
        }
    }

    private fun providerPackage(provider: String?): String? {
        return when (provider) {
            "proton_drive" -> firstInstalledPackage("me.proton.android.drive")
            "syncthing" -> firstInstalledPackage(
                "com.github.catfriend1.syncthingandroid",
                "com.nutomic.syncthingandroid"
            )
            else -> null
        }
    }

    private fun firstInstalledPackage(vararg packageNames: String): String? {
        return packageNames.firstOrNull(::isPackageInstalled)
    }

    companion object {
        private const val RequestTree = 4201
        private const val RequestOpenImage = 4202
        private const val RequestCreateImage = 4203
    }
}
