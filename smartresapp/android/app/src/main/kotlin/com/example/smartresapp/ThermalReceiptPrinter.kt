package com.example.smartresapp

import android.app.Activity
import android.content.Context
import android.os.Bundle
import android.os.CancellationSignal
import android.os.ParcelFileDescriptor
import android.print.PageRange
import android.print.PrintAttributes
import android.print.PrintDocumentAdapter
import android.print.PrintDocumentInfo
import android.print.PrintManager
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.FileOutputStream
import java.io.IOException
import kotlin.math.roundToInt

/** Preserve the roll's actual size instead of falling back to a standard sheet. */
internal object ThermalReceiptPrinter {
    fun register(activity: Activity, messenger: BinaryMessenger) {
        MethodChannel(messenger, "smartres/receipt_printing").setMethodCallHandler { call, result ->
            if (call.method != "printReceipt") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            val bytes = call.argument<ByteArray>("bytes")
            val width = call.argument<Number>("width")?.toDouble()
            val height = call.argument<Number>("height")?.toDouble()
            val name = call.argument<String>("name") ?: "SmartRes.pdf"
            if (bytes == null || bytes.isEmpty() || width == null || height == null ||
                !width.isFinite() || !height.isFinite() || width <= 0 || height <= 0) {
                result.error("RECEIPT_DATA", "Dữ liệu bill không hợp lệ", null)
                return@setMethodCallHandler
            }
            try {
                val media = PrintAttributes.MediaSize(
                    "smartres_thermal_80", "Bill 80 mm",
                    (width * 1000 / 72).roundToInt(),
                    (height * 1000 / 72).roundToInt(),
                )
                val attributes = PrintAttributes.Builder()
                    .setMediaSize(media)
                    // The PDF already includes its own symmetric 4 mm margins.
                    .setMinMargins(PrintAttributes.Margins.NO_MARGINS)
                    .build()
                val manager = activity.getSystemService(Context.PRINT_SERVICE) as PrintManager
                manager.print(name, ReceiptAdapter(name, bytes), attributes)
                result.success(null)
            } catch (error: RuntimeException) {
                result.error("RECEIPT_PRINT", "Không mở được chức năng in bill", null)
            }
        }
    }

    private class ReceiptAdapter(private val name: String, private val bytes: ByteArray) : PrintDocumentAdapter() {
        override fun onLayout(
            oldAttributes: PrintAttributes?, newAttributes: PrintAttributes,
            cancellationSignal: CancellationSignal?, callback: LayoutResultCallback, extras: Bundle?,
        ) {
            if (cancellationSignal?.isCanceled == true) {
                callback.onLayoutCancelled()
                return
            }
            val info = PrintDocumentInfo.Builder(name)
                .setContentType(PrintDocumentInfo.CONTENT_TYPE_DOCUMENT)
                .setPageCount(1)
                .build()
            callback.onLayoutFinished(info, oldAttributes != newAttributes)
        }

        override fun onWrite(
            pages: Array<out PageRange>, destination: ParcelFileDescriptor,
            cancellationSignal: CancellationSignal?, callback: WriteResultCallback,
        ) {
            if (cancellationSignal?.isCanceled == true) {
                callback.onWriteCancelled()
                return
            }
            if (pages.none { it.start <= 0 && it.end >= 0 }) {
                callback.onWriteFinished(emptyArray<PageRange>())
                return
            }
            try {
                FileOutputStream(destination.fileDescriptor).use { it.write(bytes) }
                if (cancellationSignal?.isCanceled == true) callback.onWriteCancelled()
                else callback.onWriteFinished(arrayOf(PageRange(0, 0)))
            } catch (error: IOException) {
                callback.onWriteFailed("Không ghi được dữ liệu bill")
            }
        }
    }
}
