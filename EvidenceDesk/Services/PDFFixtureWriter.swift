import AppKit
import CoreText

/// Generates simple single-page PDFs from text. Used only for QA fixtures
/// (seeded from the `--seed-demo` launch flag); not part of the product API.
enum PDFFixtureWriter {
    static func write(text: String, to url: URL) throws {
        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792) // US Letter
        guard let consumer = CGDataConsumer(url: url as CFURL) else {
            throw NSError(domain: "PDFFixtureWriter", code: 1)
        }
        var mediaBox = pageRect
        guard let ctx = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
            throw NSError(domain: "PDFFixtureWriter", code: 2)
        }
        ctx.beginPDFPage(nil)

        let nsCtx = NSGraphicsContext(cgContext: ctx, flipped: false)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = nsCtx

        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 4
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12),
            .foregroundColor: NSColor.black,
            .paragraphStyle: paragraph
        ]
        let attributed = NSAttributedString(string: text, attributes: attributes)
        attributed.draw(in: pageRect.insetBy(dx: 48, dy: 48))

        NSGraphicsContext.restoreGraphicsState()
        ctx.endPDFPage()
        ctx.closePDF()
    }
}