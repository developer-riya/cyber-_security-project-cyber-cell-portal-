package com.example.cyberuday

import android.content.Intent
import android.database.Cursor
import android.net.Uri
import android.provider.OpenableColumns
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import java.security.MessageDigest
import java.util.Locale
import java.util.UUID

class MainActivity : FlutterActivity() {
    companion object {
        private const val SHARE_CHANNEL = "cyberuday/incoming_share"
        private val MAX_METADATA_FILE_SIZE_BYTES =
            BuildConfig.CYBER_UDAY_MAX_FILE_SIZE_BYTES
        private const val MAX_SHARE_ITEM_COUNT = 10
        private val MAX_AGGREGATE_SHARED_SIZE_BYTES =
            MAX_METADATA_FILE_SIZE_BYTES.toLong() * 2
    }

    private var eventSink: EventChannel.EventSink? = null
    private var pendingShare: Map<String, Any?>? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, SHARE_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                    pendingShare?.let { payload ->
                        events?.success(payload)
                        pendingShare = null
                    }
                }

                override fun onCancel(arguments: Any?) {
                    eventSink = null
                }
            })

        receiveShareIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        receiveShareIntent(intent)
    }

    private fun receiveShareIntent(intent: Intent?) {
        val action = intent?.action ?: return
        if (action != Intent.ACTION_SEND && action != Intent.ACTION_SEND_MULTIPLE) {
            return
        }

        val text = intent.getCharSequenceExtra(Intent.EXTRA_TEXT)
            ?.toString()
            ?.trim()
            ?.takeIf { it.isNotEmpty() }
        val defaultMimeType = intent.type?.lowercase(Locale.ROOT).orEmpty()
        val sharedUris = streamUris(intent)
        val shareLimitError = if (sharedUris.size > MAX_SHARE_ITEM_COUNT) {
            "This share contains more items than Cyber Uday can review safely at once."
        } else {
            null
        }
        val stagedAttachments = sharedUris.take(MAX_SHARE_ITEM_COUNT).map { uri ->
            attachmentMetadata(uri, defaultMimeType)
        }
        val aggregateSizeBytes = stagedAttachments.fold(0L) { total, attachment ->
            total + ((attachment["sizeBytes"] as? Long) ?: 0L)
        }
        val aggregateLimitError = if (aggregateSizeBytes > MAX_AGGREGATE_SHARED_SIZE_BYTES) {
            "The combined share is larger than Cyber Uday can review safely at once."
        } else {
            null
        }
        val intakeError = shareLimitError ?: aggregateLimitError
        val attachments = if (intakeError != null) {
            discardStagedAttachments(stagedAttachments)
            emptyList()
        } else {
            stagedAttachments
        }

        if (text == null && attachments.isEmpty() && intakeError == null) {
            return
        }

        val payload = hashMapOf<String, Any?>(
            "id" to "android-${System.currentTimeMillis()}-${intent.hashCode()}",
            "receivedAt" to System.currentTimeMillis(),
            "mimeType" to defaultMimeType,
            "text" to text,
            "sourceApplication" to sourceApplication(intent),
            "items" to attachments,
            "intakeError" to intakeError,
        )
        val sink = eventSink
        if (sink != null) {
            sink.success(payload)
        } else {
            pendingShare = payload
        }
    }

    @Suppress("DEPRECATION")
    private fun streamUris(intent: Intent): List<Uri> {
        val extraUris = when (intent.action) {
            Intent.ACTION_SEND -> {
                intent.getParcelableExtra<Uri>(Intent.EXTRA_STREAM)?.let(::listOf)
                    ?: emptyList()
            }
            Intent.ACTION_SEND_MULTIPLE -> {
                intent.getParcelableArrayListExtra<Uri>(Intent.EXTRA_STREAM)?.toList()
                    ?: emptyList()
            }
            else -> emptyList()
        }
        if (extraUris.isNotEmpty()) return extraUris.distinct()

        val clipData = intent.clipData ?: return emptyList()
        return (0 until clipData.itemCount)
            .mapNotNull { index -> clipData.getItemAt(index).uri }
            .distinct()
    }

    private fun attachmentMetadata(uri: Uri, fallbackMimeType: String): Map<String, Any?> {
        var fileName: String? = null
        var sizeBytes: Long? = null
        var accessError: String? = null

        try {
            val projection = arrayOf(OpenableColumns.DISPLAY_NAME, OpenableColumns.SIZE)
            contentResolver.query(uri, projection, null, null, null).use { cursor: Cursor? ->
                if (cursor != null && cursor.moveToFirst()) {
                    val nameIndex = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                    val sizeIndex = cursor.getColumnIndex(OpenableColumns.SIZE)
                    if (nameIndex >= 0 && !cursor.isNull(nameIndex)) {
                        fileName = cursor.getString(nameIndex)
                    }
                    if (sizeIndex >= 0 && !cursor.isNull(sizeIndex)) {
                        sizeBytes = cursor.getLong(sizeIndex)
                    }
                }
            }
        } catch (_: SecurityException) {
            accessError = "The source app did not grant access to this file."
        } catch (_: Exception) {
            accessError = "Cyber Uday could not read this file metadata."
        }

        if (sizeBytes != null && sizeBytes > MAX_METADATA_FILE_SIZE_BYTES) {
            accessError = "This file is larger than the safe review limit."
        }

        val mimeType = try {
            contentResolver.getType(uri)
                ?.lowercase(Locale.ROOT)
                ?.takeIf { it.isNotBlank() }
                ?: fallbackMimeType
        } catch (_: SecurityException) {
            accessError = accessError ?: "The source app did not grant access to this file."
            fallbackMimeType
        }
        val staged = if (accessError == null) stageForTemporaryQuarantine(uri, sizeBytes) else null
        if (staged?.error != null) {
            accessError = staged.error
        }
        val intakeUri = staged?.file?.let(Uri::fromFile) ?: uri
        val detectedMimeType = detectMimeType(intakeUri)
        val fileTypeMismatch = detectedMimeType != null &&
            !mimeTypesCompatible(mimeType, detectedMimeType)
        return hashMapOf(
            "uri" to intakeUri.toString(),
            "mimeType" to mimeType,
            "contentType" to contentTypeFor(
                detectedMimeType ?: mimeType,
                fileName,
            ),
            "detectedMimeType" to detectedMimeType,
            "fileTypeMismatch" to fileTypeMismatch,
            "fileName" to fileName,
            "sizeBytes" to sizeBytes,
            "sha256" to sha256ForUri(intakeUri, staged?.sizeBytes ?: sizeBytes),
            "isTemporaryQuarantineSource" to (staged?.file != null),
            "isAccessible" to (accessError == null && staged?.file != null),
            "error" to accessError,
        )
    }

    private fun discardStagedAttachments(attachments: List<Map<String, Any?>>) {
        attachments.forEach { attachment ->
            if (attachment["isTemporaryQuarantineSource"] != true) return@forEach
            val uri = (attachment["uri"] as? String)?.let(Uri::parse) ?: return@forEach
            if (uri.scheme != "file") return@forEach
            runCatching {
                uri.path?.let(::File)?.delete()
            }
        }
    }

    private fun stageForTemporaryQuarantine(uri: Uri, declaredSize: Long?): StagedContent {
        if (declaredSize != null && declaredSize > MAX_METADATA_FILE_SIZE_BYTES) {
            return StagedContent(error = "This file is larger than the safe review limit.")
        }
        val directory = File(cacheDir, "cyber-uday-intake")
        if (!directory.exists() && !directory.mkdirs()) {
            return StagedContent(error = "Cyber Uday could not prepare temporary file quarantine.")
        }
        val destination = File(directory, "item-${UUID.randomUUID()}.bin")
        return try {
            openInputStream(uri)?.use { input ->
                FileOutputStream(destination).use { output ->
                    val buffer = ByteArray(8192)
                    var total = 0L
                    while (true) {
                        val count = input.read(buffer)
                        if (count <= 0) break
                        total += count
                        if (total > MAX_METADATA_FILE_SIZE_BYTES) {
                            destination.delete()
                            return StagedContent(
                                error = "This file is larger than the safe review limit.",
                            )
                        }
                        output.write(buffer, 0, count)
                    }
                    StagedContent(file = destination, sizeBytes = total)
                }
            } ?: StagedContent(error = "The source app did not grant access to this file.")
        } catch (_: Exception) {
            destination.delete()
            StagedContent(error = "Cyber Uday could not quarantine this shared file.")
        }
    }

    @Suppress("DEPRECATION")
    private fun sourceApplication(intent: Intent): String? {
        return intent.getParcelableExtra<Uri>(Intent.EXTRA_REFERRER)?.host
    }

    private fun contentTypeFor(mimeType: String, fileName: String?): String {
        val extension = fileName
            ?.substringAfterLast('.', "")
            ?.lowercase(Locale.ROOT)
            .orEmpty()
        return when {
        mimeType.startsWith("image/") -> "image"
        mimeType == "application/pdf" -> "pdf"
        mimeType == "application/vnd.android.package-archive" || extension == "apk" -> "apk"
        mimeType.startsWith("audio/") -> "audio"
        mimeType.startsWith("video/") -> "video"
        mimeType == "application/zip" ||
            mimeType == "application/x-7z-compressed" ||
            mimeType == "application/x-rar-compressed" ||
            mimeType == "application/gzip" ||
            mimeType == "application/x-tar" ||
            extension in setOf("zip", "7z", "rar", "gz", "tar") -> "archive"
        mimeType == "application/x-executable" ||
            mimeType == "application/vnd.microsoft.portable-executable" ||
            extension in setOf("exe", "bin", "elf") -> "executable"
        mimeType == "application/x-sh" ||
            mimeType == "application/x-bat" ||
            mimeType == "text/x-python" ||
            mimeType == "text/javascript" ||
            extension in setOf("sh", "bat", "cmd", "js", "py", "ps1") -> "script"
        mimeType.startsWith("text/") ||
            mimeType.contains("word") ||
            mimeType.contains("document") ||
            mimeType.contains("spreadsheet") ||
            mimeType.contains("excel") -> "document"
        else -> "unsupported"
        }
    }

    private fun detectMimeType(uri: Uri): String? {
        return try {
            openInputStream(uri)?.use { input ->
                val header = ByteArray(16)
                val count = input.read(header)
                if (count < 4) return null
                when {
                    header.copyOfRange(0, 4).contentEquals(
                        byteArrayOf(0x25, 0x50, 0x44, 0x46),
                    ) -> "application/pdf"
                    header.copyOfRange(0, 8).contentEquals(
                        byteArrayOf(
                            0x89.toByte(), 0x50, 0x4E, 0x47,
                            0x0D, 0x0A, 0x1A, 0x0A,
                        ),
                    ) -> "image/png"
                    header.copyOfRange(0, 3).contentEquals(
                        byteArrayOf(0xFF.toByte(), 0xD8.toByte(), 0xFF.toByte()),
                    ) -> "image/jpeg"
                    header.copyOfRange(0, 4).contentEquals(
                        byteArrayOf(0x50, 0x4B, 0x03, 0x04),
                    ) -> "application/zip"
                    header.copyOfRange(0, 4).contentEquals(
                        byteArrayOf(0x47, 0x49, 0x46, 0x38),
                    ) -> "image/gif"
                    else -> null
                }
            }
        } catch (_: Exception) {
            null
        }
    }

    private fun mimeTypesCompatible(declared: String, detected: String): Boolean {
        if (declared.isBlank() || declared == "*/*") return true
        if (declared == detected) return true
        return declared == "application/vnd.android.package-archive" &&
            detected == "application/zip"
    }

    private fun sha256ForUri(uri: Uri, sizeBytes: Long?): String? {
        if (sizeBytes != null && sizeBytes > MAX_METADATA_FILE_SIZE_BYTES) return null
        return try {
            openInputStream(uri)?.use { input ->
                val digest = MessageDigest.getInstance("SHA-256")
                val buffer = ByteArray(8192)
                var total = 0L
                while (true) {
                    val count = input.read(buffer)
                    if (count <= 0) break
                    total += count
                    if (total > MAX_METADATA_FILE_SIZE_BYTES) return null
                    digest.update(buffer, 0, count)
                }
                digest.digest().joinToString("") { byte -> "%02x".format(byte) }
            }
        } catch (_: Exception) {
            null
        }
    }

    private fun openInputStream(uri: Uri) = if (uri.scheme == "file") {
        uri.path?.let(::File)?.let(::FileInputStream)
    } else {
        contentResolver.openInputStream(uri)
    }

    private data class StagedContent(
        val file: File? = null,
        val sizeBytes: Long? = null,
        val error: String? = null,
    )
}
