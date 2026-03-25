import AppKit
import ApplicationServices
import Foundation
import Vision
import WebKit
import ImageIO

enum WukongAppError: LocalizedError {
    case missingResource(String)
    case invalidPayload(String)
    case invalidURL(String)
    case invalidImageData
    case unsupportedAction(String)
    case appNotRunning
    case noVisibleWindow
    case serializationFailed

    var errorDescription: String? {
        switch self {
        case .missingResource(let name):
            return "Missing resource: \(name)"
        case .invalidPayload(let reason):
            return reason
        case .invalidURL(let value):
            return "Invalid image URL: \(value)"
        case .invalidImageData:
            return "Failed to decode image data."
        case .unsupportedAction(let action):
            return "Unsupported native bridge action: \(action)"
        case .appNotRunning:
            return "Wukong app process not found. Open the app first and keep it on the invite page."
        case .noVisibleWindow:
            return "Wukong app has no visible window."
        case .serializationFailed:
            return "Failed to serialize native bridge payload."
        }
    }
}

struct OCRRecord {
    let label: String
    let candidate: String
    let rawText: String
    let score: Double

    var jsonObject: [String: Any] {
        [
            "label": label,
            "candidate": candidate,
            "raw_text": rawText,
            "score": score.isFinite ? score : NSNull(),
        ]
    }
}

final class NativeBridgeHandler: NSObject, WKScriptMessageHandler {
    private weak var webView: WKWebView?
    private let stopWords: Set<String> = [
        "限量邀请码",
        "当前邀请码",
        "欢迎回来吧",
        "立即体验吧",
        "退出登录吧",
        "悟空官网获得",
        "限量",
        "已领完",
        "欢迎回来",
        "立即体验",
        "退出登录",
    ]
    private let processNameHints = ["Wukong", "悟空"]
    private let bundleNameHints = ["Wukong.app"]

    init(webView: WKWebView) {
        self.webView = webView
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == "wukongBridge" else { return }
        guard let body = message.body as? [String: Any],
              let id = body["id"] as? Int,
              let action = body["action"] as? String else {
            return
        }

        let payload = body["payload"] as? [String: Any] ?? [:]
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let result = try self.handle(action: action, payload: payload)
                DispatchQueue.main.async {
                    self.resolve(id: id, payload: result)
                }
            } catch {
                let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                DispatchQueue.main.async {
                    self.reject(id: id, message: message)
                }
            }
        }
    }

    private func handle(action: String, payload: [String: Any]) throws -> [String: Any] {
        switch action {
        case "health":
            return healthPayload()
        case "ocr":
            return try runOCR(payload: payload)
        case "fill-app":
            return try fillWukongApp(payload: payload)
        default:
            throw WukongAppError.unsupportedAction(action)
        }
    }

    private func healthPayload() -> [String: Any] {
        [
            "ok": true,
            "platform": "Darwin",
            "mode": "macos-native-app",
            "diagnostics": permissionDiagnostics(),
        ]
    }

    private func runOCR(payload: [String: Any]) throws -> [String: Any] {
        guard let imageURLString = payload["image_url"] as? String, !imageURLString.isEmpty else {
            throw WukongAppError.invalidPayload("image_url is required.")
        }

        var records: [OCRRecord] = []
        var bestRecord = OCRRecord(label: "original", candidate: "", rawText: "", score: -.infinity)

        func evaluate(label: String, imageData: Data) throws {
            let cgImage = try makeCGImage(from: imageData)
            let rawText = try recognizeText(in: cgImage)
            let extracted = extractBestCandidate(from: rawText)
            let record = OCRRecord(label: label, candidate: extracted.candidate, rawText: rawText, score: extracted.score)
            records.append(record)
            if record.score > bestRecord.score {
                bestRecord = record
            }
        }

        if let variants = payload["variants"] as? [[String: Any]] {
            for (index, variant) in variants.enumerated() {
                guard let dataURL = variant["image_data_url"] as? String, !dataURL.isEmpty else {
                    continue
                }
                let label = (variant["label"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? "browser-variant-\(index + 1)"
                do {
                    let imageData = try decodeDataURL(dataURL)
                    try evaluate(label: label, imageData: imageData)
                } catch {
                    continue
                }
            }
        }

        let remoteData = try downloadImage(from: imageURLString)
        try evaluate(label: "original", imageData: remoteData)

        return [
            "candidate": bestRecord.candidate,
            "raw_text": bestRecord.rawText,
            "label": "macOS Native OCR · \(bestRecord.label)",
            "score": bestRecord.score.isFinite ? bestRecord.score : NSNull(),
            "records": records.map(\.jsonObject),
        ]
    }

    private func fillWukongApp(payload: [String: Any]) throws -> [String: Any] {
        guard let code = payload["code"] as? String, !code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw WukongAppError.invalidPayload("code is required.")
        }
        let submit = payload["submit"] as? Bool ?? true
        let targetApp = try resolveTargetApp()
        let fillMethod = try runFillScript(processID: targetApp.processIdentifier, inviteCode: code.trimmingCharacters(in: .whitespacesAndNewlines), submit: submit)

        return [
            "ok": true,
            "process_name": targetApp.localizedName ?? "",
            "unix_id": Int(targetApp.processIdentifier),
            "submitted": submit,
            "mode": "native-ui-script",
            "fill_method": fillMethod,
            "match_strategy": "running-application-bundle-url",
        ]
    }

    private func resolveTargetApp() throws -> NSRunningApplication {
        let runningApps = NSWorkspace.shared.runningApplications.filter { !$0.isTerminated }

        if let app = runningApps.first(where: { app in
            let name = app.localizedName ?? ""
            return processNameHints.contains(where: { name.localizedCaseInsensitiveContains($0) })
        }) {
            return app
        }

        if let app = runningApps.first(where: { app in
            guard let path = app.bundleURL?.path else { return false }
            return bundleNameHints.contains(where: { path.contains("/\($0)") })
        }) {
            return app
        }

        throw WukongAppError.appNotRunning
    }

    private func permissionDiagnostics() -> [String: Any] {
        let bundlePath = Bundle.main.bundleURL.path
        let bundleIdentifier = Bundle.main.bundleIdentifier ?? ""
        let permissionTargetLabel =
            (Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String) ??
            (Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String) ??
            Bundle.main.bundleURL.deletingPathExtension().lastPathComponent

        return [
            "runner_type": "native-standalone",
            "runner_pid": Int(ProcessInfo.processInfo.processIdentifier),
            "bundle_id": bundleIdentifier,
            "permission_target_label": permissionTargetLabel,
            "permission_target_path": bundlePath,
            "ax_trusted": AXIsProcessTrusted(),
            "system_events_probe": diagnoseSystemEventsProbe(),
        ]
    }

    private func diagnoseSystemEventsProbe() -> [String: Any] {
        do {
            let detail = try runAppleScript(#"tell application "System Events" to count of application processes"#)
            return [
                "ok": true,
                "detail": detail,
            ]
        } catch {
            let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            return [
                "ok": false,
                "detail": message,
            ]
        }
    }

    private func runFillScript(processID: pid_t, inviteCode: String, submit: Bool) throws -> String {
        let submitFlag = submit ? "true" : "false"
        let script = """
        on findFirstInput(targetWindow)
            tell application "System Events"
                set uiItems to entire contents of targetWindow
                repeat with uiItem in uiItems
                    try
                        set uiRole to role of uiItem as text
                        if uiRole is "AXTextField" or uiRole is "AXTextArea" or uiRole is "AXComboBox" then
                            return uiItem
                        end if
                    end try
                end repeat
            end tell
            return missing value
        end findFirstInput

        on clickSubmitButton(targetWindow)
            tell application "System Events"
                set uiItems to entire contents of targetWindow
                repeat with uiItem in uiItems
                    try
                        if (role of uiItem as text) is "AXButton" then
                            set buttonName to ""
                            try
                                set buttonName to name of uiItem as text
                            end try
                            if buttonName contains "立即体验" then
                                click uiItem
                                return true
                            end if
                        end if
                    end try
                end repeat
            end tell
            return false
        end clickSubmitButton

        on focusInput(targetInput)
            if targetInput is missing value then
                return false
            end if

            tell application "System Events"
                try
                    perform action "AXPress" of targetInput
                end try
                try
                    set focused of targetInput to true
                end try
            end tell
            delay 0.15
            return true
        end focusInput

        on replaceTextByPaste(targetInput, inviteCode)
            set clipboardBackup to missing value
            set hasClipboardBackup to false

            my focusInput(targetInput)

            try
                set clipboardBackup to the clipboard
                set hasClipboardBackup to true
            end try
            set the clipboard to inviteCode

            tell application "System Events"
                keystroke "a" using command down
                delay 0.08
                key code 51
                delay 0.08
                keystroke "v" using command down
            end tell
            delay 0.18

            if hasClipboardBackup then
                set the clipboard to clipboardBackup
            end if

            return "clipboard-paste"
        end replaceTextByPaste

        on fillInviteCode(targetInput, inviteCode)
            tell application "System Events"
                if targetInput is not missing value then
                    try
                        set value of targetInput to inviteCode
                        return "set-value"
                    end try
                end if
            end tell

            my focusInput(targetInput)

            tell application "System Events"
                if targetInput is not missing value then
                    try
                        set value of targetInput to inviteCode
                        return "focused-set-value"
                    end try
                end if
            end tell

            try
                return my replaceTextByPaste(targetInput, inviteCode)
            on error
                my focusInput(targetInput)
                tell application "System Events"
                    keystroke "a" using command down
                    delay 0.08
                    key code 51
                    delay 0.08
                    keystroke inviteCode
                end tell
                delay 0.18
            end try
            return "keystroke"
        end fillInviteCode

        set targetPid to \(processID)
        set inviteCode to \(appleScriptQuote(inviteCode))
        set shouldSubmit to \(submitFlag)
        set targetWindow to missing value
        set clickedSubmit to false
        set fillMethod to "unknown"

        tell application "System Events"
            set targetProcess to first application process whose unix id is targetPid
            tell targetProcess
                set frontmost to true
            end tell
        end tell
        delay 0.6

        tell application "System Events"
            tell targetProcess
                if (count of windows) is 0 then
                    error "Wukong app has no visible window."
                end if
                set frontmost to true
                set targetWindow to front window
                set targetInput to my findFirstInput(targetWindow)
                my focusInput(targetInput)
            end tell

            set fillMethod to my fillInviteCode(targetInput, inviteCode)
            delay 0.35

            if shouldSubmit then
                set clickedSubmit to my clickSubmitButton(targetWindow)
                if clickedSubmit is false then
                    keystroke return
                end if
            end if
        end tell

        if clickedSubmit then
            return "button"
        end if

        if shouldSubmit then
            return "return"
        end if

        return fillMethod
        """

        return try runAppleScript(script)
    }

    private func makeCGImage(from data: Data) throws -> CGImage {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw WukongAppError.invalidImageData
        }
        return image
    }

    private func decodeDataURL(_ dataURL: String) throws -> Data {
        guard dataURL.hasPrefix("data:image/"), let commaIndex = dataURL.firstIndex(of: ",") else {
            throw WukongAppError.invalidPayload("Unsupported image_data_url payload.")
        }
        let encoded = String(dataURL[dataURL.index(after: commaIndex)...])
        guard let data = Data(base64Encoded: encoded) else {
            throw WukongAppError.invalidPayload("Malformed image_data_url payload.")
        }
        return data
    }

    private func downloadImage(from imageURLString: String) throws -> Data {
        guard let url = URL(string: imageURLString), let scheme = url.scheme?.lowercased(), ["http", "https"].contains(scheme) else {
            throw WukongAppError.invalidURL(imageURLString)
        }
        let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15)
        let semaphore = DispatchSemaphore(value: 0)
        var downloadedData: Data?
        var downloadError: Error?
        URLSession.shared.dataTask(with: request) { data, _, error in
            downloadedData = data
            downloadError = error
            semaphore.signal()
        }.resume()
        semaphore.wait()

        if let downloadError {
            throw downloadError
        }
        guard let downloadedData, !downloadedData.isEmpty else {
            throw WukongAppError.invalidPayload("Downloaded image is empty.")
        }
        return downloadedData
    }

    private func recognizeText(in image: CGImage) throws -> String {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["zh-Hans", "en-US"]
        request.usesLanguageCorrection = true
        if #available(macOS 13.0, *) {
            request.automaticallyDetectsLanguage = true
            request.revision = VNRecognizeTextRequestRevision3
        }

        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        try handler.perform([request])

        let strings = (request.results ?? []).flatMap { observation -> [String] in
            observation.topCandidates(3).map(\.string)
        }
        return strings.joined(separator: "\n")
    }

    private func extractBestCandidate(from text: String) -> (candidate: String, score: Double) {
        let normalized = text
            .replacingOccurrences(of: "\u{3000}", with: " ")
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let labelPatterns = [
            #"当前邀请码\s*[:：]?\s*([\p{Han}]{5})"#,
            #"邀请码\s*[:：]?\s*([\p{Han}]{5})"#,
        ]

        for pattern in labelPatterns {
            if let match = firstCaptureMatch(pattern: pattern, in: normalized) {
                return (match, scoreChineseCandidate(match) + 6)
            }
        }

        var exactFive: [String] = []
        for token in allMatches(pattern: #"[\p{Han}]{5}"#, in: normalized) {
            if stopWords.contains(token) { continue }
            if !exactFive.contains(token) {
                exactFive.append(token)
            }
        }
        if exactFive.count == 1, let candidate = exactFive.first {
            return (candidate, scoreChineseCandidate(candidate) + 4)
        }

        var ranked: [(candidate: String, score: Double)] = []
        var seen = Set<String>()
        let compactLines = normalized
            .split(separator: "\n")
            .map { $0.replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "\t", with: "").trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        for rawLine in compactLines {
            let line = rawLine
                .replacingOccurrences(of: "当前邀请码", with: "")
                .replacingOccurrences(of: "邀请码", with: "")
                .replacingOccurrences(of: "已领完", with: "")
                .replacingOccurrences(of: "限量", with: "")

            var candidates = [line]
            candidates.append(contentsOf: allMatches(pattern: #"[\p{Han}]{3,10}"#, in: line))
            for candidate in candidates {
                let trimmed = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty || stopWords.contains(trimmed) || seen.contains(trimmed) {
                    continue
                }
                seen.insert(trimmed)
                let score = scoreChineseCandidate(trimmed)
                if score > 0 {
                    ranked.append((trimmed, score))
                }
            }
        }

        if let best = ranked.sorted(by: { lhs, rhs in
            if lhs.score == rhs.score {
                return lhs.candidate.count < rhs.candidate.count
            }
            return lhs.score > rhs.score
        }).first {
            return best
        }

        return ("", -.infinity)
    }

    private func scoreChineseCandidate(_ text: String) -> Double {
        let hanScalars = text.unicodeScalars.filter { scalar in
            (0x4E00...0x9FFF).contains(Int(scalar.value))
        }
        let count = hanScalars.count
        if count == 0 {
            return -.infinity
        }

        var score = 0.0
        if count == 5 {
            score += 10
        } else {
            score += Double(max(0, 5 - abs(count - 5)))
        }

        if text.range(of: #"^[\p{Han}]+$"#, options: .regularExpression) != nil {
            score += 2
        }

        if count == text.count {
            score += 1
        }

        if !stopWords.contains(text) {
            score += 1
        }
        return score
    }

    private func firstCaptureMatch(pattern: String, in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, range: range), match.numberOfRanges > 1,
              let captureRange = Range(match.range(at: 1), in: text) else {
            return nil
        }
        return String(text[captureRange])
    }

    private func allMatches(pattern: String, in text: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.matches(in: text, range: range).compactMap { match in
            guard let matchRange = Range(match.range(at: 0), in: text) else { return nil }
            return String(text[matchRange])
        }
    }

    private func runAppleScript(_ script: String) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        try process.run()
        process.waitUntilExit()

        let stdout = String(data: stdoutPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let stderr = String(data: stderrPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        if process.terminationStatus != 0 {
            throw NSError(domain: "WukongInviteGrabber.AppleScript", code: Int(process.terminationStatus), userInfo: [
                NSLocalizedDescriptionKey: stderr.isEmpty ? stdout : stderr,
            ])
        }
        return stdout
    }

    private func appleScriptQuote(_ value: String) -> String {
        let escaped = value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\(escaped)\""
    }

    private func resolve(id: Int, payload: [String: Any]) {
        guard let webView else { return }
        guard let jsonData = try? JSONSerialization.data(withJSONObject: payload, options: []),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            reject(id: id, message: WukongAppError.serializationFailed.localizedDescription)
            return
        }
        webView.evaluateJavaScript("window.__wukongBridgeResolve(\(id), \(jsonString));", completionHandler: nil)
    }

    private func reject(id: Int, message: String) {
        guard let webView else { return }
        let escaped = jsStringLiteral(message)
        webView.evaluateJavaScript("window.__wukongBridgeReject(\(id), \(escaped));", completionHandler: nil)
    }

    private func jsStringLiteral(_ value: String) -> String {
        let escaped = value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
        return "\"\(escaped)\""
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var window: NSWindow?
    private var webView: WKWebView?
    private var bridgeHandler: NativeBridgeHandler?

    func applicationDidFinishLaunching(_ notification: Notification) {
        do {
            try buildWindow()
        } catch {
            showFatalError(message: error.localizedDescription)
            NSApp.terminate(nil)
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    private func buildWindow() throws {
        let contentController = WKUserContentController()
        let configuration = WKWebViewConfiguration()
        configuration.userContentController = contentController

        let bootstrapScript = """
        (() => {
          const pending = new Map();
          let nextId = 1;
          window.__wukongBridgeResolve = (id, payload) => {
            const entry = pending.get(id);
            if (!entry) return;
            pending.delete(id);
            entry.resolve(payload);
          };
          window.__wukongBridgeReject = (id, message) => {
            const entry = pending.get(id);
            if (!entry) return;
            pending.delete(id);
            entry.reject(new Error(message || "Native bridge failed."));
          };
          window.WukongNativeBridge = {
            invoke(action, payload) {
              return new Promise((resolve, reject) => {
                const id = nextId++;
                pending.set(id, { resolve, reject });
                window.webkit.messageHandlers.wukongBridge.postMessage({
                  id,
                  action,
                  payload: payload || {}
                });
              });
            }
          };
          window.WUKONG_INVITE_NATIVE_APP = true;
        })();
        """
        contentController.addUserScript(WKUserScript(source: bootstrapScript, injectionTime: .atDocumentStart, forMainFrameOnly: false))

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.setValue(false, forKey: "drawsBackground")
        let bridgeHandler = NativeBridgeHandler(webView: webView)
        contentController.add(bridgeHandler, name: "wukongBridge")

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1440, height: 960),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Wukong Invite Grabber"
        window.center()
        window.contentView = webView
        window.makeKeyAndOrderFront(nil)
        window.delegate = self

        self.window = window
        self.webView = webView
        self.bridgeHandler = bridgeHandler

        try loadFrontend(in: webView)
    }

    private func loadFrontend(in webView: WKWebView) throws {
        guard let resourceURL = Bundle.main.resourceURL else {
            throw WukongAppError.missingResource("Bundle resource URL")
        }

        let appRoot = resourceURL.appendingPathComponent("app", isDirectory: true)
        let htmlURL = appRoot.appendingPathComponent("prototype/wukong-invite-grabber.html")
        guard FileManager.default.fileExists(atPath: htmlURL.path) else {
            throw WukongAppError.missingResource("prototype/wukong-invite-grabber.html")
        }
        webView.loadFileURL(htmlURL, allowingReadAccessTo: appRoot)
    }

    private func showFatalError(message: String) {
        let alert = NSAlert()
        alert.alertStyle = .critical
        alert.messageText = "启动 Wukong Invite Grabber 失败"
        alert.informativeText = message
        alert.runModal()
    }
}

@main
struct WukongInviteGrabberStandaloneApp {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.setActivationPolicy(.regular)
        app.delegate = delegate
        app.activate(ignoringOtherApps: true)
        app.run()
    }
}
