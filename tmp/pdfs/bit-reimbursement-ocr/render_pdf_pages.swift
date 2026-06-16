import AppKit
import Foundation
import PDFKit

func usage() -> Never {
    fputs("Usage: render_pdf_pages.swift INPUT.pdf OUTPUT_DIR [DPI] [START_PAGE] [END_PAGE]\n", stderr)
    exit(2)
}

let args = CommandLine.arguments
guard args.count >= 3 else { usage() }

let inputPath = args[1]
let outputDir = args[2]
let dpi = args.count >= 4 ? (Double(args[3]) ?? 200.0) : 200.0
let startPage = args.count >= 5 ? max((Int(args[4]) ?? 1), 1) : 1
let requestedEndPage = args.count >= 6 ? (Int(args[5]) ?? Int.max) : Int.max

let inputURL = URL(fileURLWithPath: inputPath)
let outputURL = URL(fileURLWithPath: outputDir, isDirectory: true)
try FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true)

guard let document = PDFDocument(url: inputURL) else {
    fputs("Could not open PDF: \(inputPath)\n", stderr)
    exit(1)
}

let pageCount = document.pageCount
let endPage = min(max(requestedEndPage, startPage), pageCount)
let scale = dpi / 72.0

print("pages=\(pageCount) dpi=\(dpi) range=\(startPage)-\(endPage)")

for pageNumber in startPage...endPage {
    autoreleasepool {
        guard let page = document.page(at: pageNumber - 1) else { return }

        let bounds = page.bounds(for: .mediaBox)
        let pixelWidth = max(Int(bounds.width * scale), 1)
        let pixelHeight = max(Int(bounds.height * scale), 1)

        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: pixelWidth,
            pixelsHigh: pixelHeight,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            fputs("Could not allocate bitmap for page \(pageNumber)\n", stderr)
            exit(1)
        }

        bitmap.size = NSSize(width: bounds.width, height: bounds.height)

        guard let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
            fputs("Could not create graphics context for page \(pageNumber)\n", stderr)
            exit(1)
        }

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        NSColor.white.setFill()
        NSRect(origin: .zero, size: bitmap.size).fill()
        page.draw(with: .mediaBox, to: context.cgContext)
        NSGraphicsContext.restoreGraphicsState()

        guard let pngData = bitmap.representation(using: .png, properties: [:]) else {
            fputs("Could not encode PNG for page \(pageNumber)\n", stderr)
            exit(1)
        }

        let filename = String(format: "page-%03d.png", pageNumber)
        let pageURL = outputURL.appendingPathComponent(filename)
        do {
            try pngData.write(to: pageURL)
        } catch {
            fputs("Could not write \(filename): \(error)\n", stderr)
            exit(1)
        }

        print(filename)
    }
}
