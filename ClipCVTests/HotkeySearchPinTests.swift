import AppKit
import Testing
@testable import ClipCV

struct HotkeySearchPinTests {
    @Test func normalizePinKeyAcceptsLetterAndSymbol() {
        #expect(HotkeyFormatting.normalizePinKey("q") == "Q")
        #expect(HotkeyFormatting.normalizePinKey(";") == ";")
        #expect(HotkeyFormatting.normalizePinKey("ab") == nil)
        #expect(HotkeyFormatting.normalizePinKey("1") == nil)
    }

    @Test func nextPinKeySkipsUsedAndFollowsOrder() {
        #expect(HotkeyFormatting.nextPinKey(used: ["Q", "W"], order: "QWE") == "E")
        let allLetters = Set("QWERTYUIOPASDFGHJKLZXCVBNM".map(String.init))
        #expect(HotkeyFormatting.nextPinKey(used: allLetters, order: "QWE") == nil)
    }

    @Test func availablePinKeysExcludesTakenExceptCurrent() {
        let keys = HotkeyFormatting.availablePinKeys(used: ["Q", "W"], current: "Q", order: "QWE")
        #expect(keys.contains("Q"))
        #expect(keys.contains("E"))
        #expect(!keys.contains("W"))
    }

    @Test func normalizePinOrderDedupesAndUppercases() {
        #expect(HotkeyFormatting.normalizePinOrder("qQwE1") == "QWE")
        #expect(HotkeyFormatting.normalizeUnpinnedOrder("11230a") == "1230A")
    }

    @Test func searchExactAndFuzzyMatchHaystacks() {
        let hay = ["Hello World", "ClipCV"]
        #expect(SearchService.matches(haystacks: hay, query: "hello", mode: .exact))
        #expect(SearchService.matches(haystacks: hay, query: "hlo", mode: .fuzzy))
        #expect(!SearchService.matches(haystacks: hay, query: "zzz", mode: .exact))
    }

    @Test func searchForcesExactWhenKeywordTooLongForFuzzy() {
        let long = String(repeating: "a", count: 80)
        let hay = [long + "tail"]
        #expect(SearchService.matches(haystacks: hay, query: long, mode: .fuzzy))
    }

    @Test func searchRegexpFallsBackWhenPatternInvalid() {
        #expect(SearchService.matches(haystacks: ["price (sale)"], query: "(", mode: .regexp))
        #expect(SearchService.matches(haystacks: ["abc123"], query: #"\d+"#, mode: .regexp))
    }

    @Test func pinOrderMovingInsertsBeforeTarget() {
        let a = UUID()
        let b = UUID()
        let c = UUID()
        #expect(PinOrder.moving([a, b, c], moving: c, before: a) == [c, a, b])
        #expect(PinOrder.moving([a, b, c], moving: a, before: c) == [b, a, c])
        #expect(PinOrder.moving([a, b], moving: a, before: a) == [a, b])
        #expect(PinOrder.moving([a, b], moving: UUID(), before: a) == nil)
    }

    @Test func thumbnailMakeShrinksLargePNG() {
        let large = NSImage(size: NSSize(width: 400, height: 200))
        large.lockFocus()
        NSColor.red.setFill()
        NSRect(x: 0, y: 0, width: 400, height: 200).fill()
        large.unlockFocus()
        guard let tiff = large.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]),
              let small = ThumbnailCache.make(from: png, maxSide: 100)
        else {
            Issue.record("failed to build test PNG")
            return
        }
        #expect(max(small.size.width, small.size.height) <= 100.5)
    }

    @Test func OCRRejectsNonImageData() async {
        let text = await OCRService.recognizeText(in: Data("Not an image".utf8))
        #expect(text == nil)
    }

    @Test @MainActor func OCRRecognizesImageText() async throws {
        let image = NSImage(size: NSSize(width: 600, height: 160))
        image.lockFocus()
        NSColor.white.setFill()
        NSRect(x: 0, y: 0, width: 600, height: 160).fill()
        NSAttributedString(string: "CLIPCV 2468", attributes: [
            .font: NSFont.monospacedSystemFont(ofSize: 50, weight: .bold),
            .foregroundColor: NSColor.black,
        ]).draw(at: NSPoint(x: 20, y: 50))
        image.unlockFocus()
        let data = try #require(image.tiffRepresentation)

        let result = await OCRService.recognizeText(in: data)

        let text = try #require(result)
        #expect(text.contains("2468"))
    }

    @Test func preferPNGDropsTIFFWhenBothPresent() {
        let png = ClipboardPayload(type: ClipboardRules.Kind.png, data: Data([0x89, 0x50]))
        let tiff = ClipboardPayload(type: ClipboardRules.Kind.tiff, data: Data([0x49, 0x49]))
        let text = ClipboardPayload(type: ClipboardRules.Kind.string, data: Data("hi".utf8))
        let result = ClipboardRules.preferPNGOverTIFF([text, png, tiff])
        #expect(result.count == 2)
        #expect(result.contains { $0.type == ClipboardRules.Kind.png })
        #expect(!result.contains { $0.type == ClipboardRules.Kind.tiff })
    }

    @Test func prepareForStorageScalesByPercent() {
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: 400,
            pixelsHigh: 200,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            Issue.record("failed to build test bitmap")
            return
        }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        NSColor.blue.setFill()
        NSRect(x: 0, y: 0, width: 400, height: 200).fill()
        NSGraphicsContext.restoreGraphicsState()
        guard let painted = rep.representation(using: .png, properties: [:]) else {
            Issue.record("failed to encode painted PNG")
            return
        }
        let payload = ClipboardPayload(type: ClipboardRules.Kind.png, data: painted)
        let scaled = ClipboardRules.prepareForStorage([payload], scalePercent: 50)
        guard let data = scaled.first?.data,
              let size = ThumbnailCache.pixelSize(of: data)
        else {
            Issue.record("scaled image missing")
            return
        }
        #expect(max(size.width, size.height) <= 200)
    }
}
