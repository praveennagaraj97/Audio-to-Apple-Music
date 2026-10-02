import AppKit
import Foundation
import UniformTypeIdentifiers

private let appName = "Audio to Apple Music"
private let supportedExtensions: Set<String> = ["flac", "wav", "aif", "aiff", "mp3", "aac", "m4a"]

@main
struct AudioToMusicApp {
    static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.regular)
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
}

private struct MediaInfo {
    var title: String
    var artist: String
    var album: String
    var hasArtwork: Bool
    var artwork: NSImage?

    static let unavailable = MediaInfo(title: "Unknown title", artist: "Unknown artist", album: "Unknown album", hasArtwork: false, artwork: nil)
}

private struct TrackReport {
    let filename: String
    var info: MediaInfo
    var conversion = "Not converted"
    var importResult = "Not imported"
    var outputCleanup = "Not cleaned up"
    var sourceCleanup = "Original file kept in place."
    var error: String?
}

private struct ProbeResult: Decodable {
    struct Format: Decodable { var tags: [String: String]? }
    struct Disposition: Decodable { var attached_pic: Int? }
    struct Stream: Decodable {
        var codec_type: String?
        var disposition: Disposition?
        var tags: [String: String]?
    }
    var format: Format?
    var streams: [Stream]?
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow!
    private var sources: [URL] = []
    private var sourceSummary: NSTextField!
    private var progress: NSProgressIndicator!
    private var status: NSTextField!
    private var convertButton: NSButton!
    private var reportsStack: NSStackView!
    private var reportScroll: NSScrollView!

    func applicationDidFinishLaunching(_ notification: Notification) { buildWindow() }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    private func buildWindow() {
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 720, height: 680), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.title = appName
        window.center()

        let root = NSStackView()
        root.orientation = .vertical
        root.alignment = .leading
        root.spacing = 14
        root.translatesAutoresizingMaskIntoConstraints = false
        root.edgeInsets = NSEdgeInsets(top: 22, left: 24, bottom: 22, right: 24)
        window.contentView = root

        let header = NSTextField(labelWithString: appName)
        header.font = .boldSystemFont(ofSize: 26)
        root.addArrangedSubview(header)
        let subtitle = NSTextField(wrappingLabelWithString: "Convert FLAC, WAV, AIFF, MP3, and AAC/M4A files to Apple Lossless (ALAC), then add them to your local Music library. No subscription is needed.")
        subtitle.textColor = .secondaryLabelColor
        root.addArrangedSubview(subtitle)

        let sourceButtons = NSStackView()
        sourceButtons.orientation = .horizontal
        sourceButtons.spacing = 10
        sourceButtons.addArrangedSubview(button("Choose Audio Files…", #selector(chooseFiles)))
        sourceButtons.addArrangedSubview(button("Choose Folder…", #selector(chooseFolder)))
        root.addArrangedSubview(sourceButtons)

        sourceSummary = NSTextField(wrappingLabelWithString: "Choose audio files or a folder to scan.")
        sourceSummary.textColor = .secondaryLabelColor
        sourceSummary.maximumNumberOfLines = 3
        root.addArrangedSubview(sourceSummary)

        convertButton = button("Convert & Add to Music", #selector(convert))
        convertButton.bezelStyle = .rounded
        convertButton.keyEquivalent = "\r"
        convertButton.isEnabled = false
        root.addArrangedSubview(convertButton)

        progress = NSProgressIndicator()
        progress.style = .bar
        progress.isIndeterminate = false
        progress.minValue = 0
        progress.maxValue = 1
        progress.doubleValue = 0
        progress.isHidden = true
        root.addArrangedSubview(progress)

        status = NSTextField(wrappingLabelWithString: "Completed conversions will appear below with artwork and import details.")
        status.textColor = .secondaryLabelColor
        root.addArrangedSubview(status)

        reportsStack = NSStackView()
        reportsStack.orientation = .vertical
        reportsStack.alignment = .leading
        reportsStack.spacing = 10
        reportsStack.translatesAutoresizingMaskIntoConstraints = false
        reportScroll = NSScrollView()
        reportScroll.hasVerticalScroller = true
        reportScroll.borderType = .bezelBorder
        reportScroll.documentView = reportsStack
        reportScroll.translatesAutoresizingMaskIntoConstraints = false
        root.addArrangedSubview(reportScroll)

        NSLayoutConstraint.activate([
            root.leadingAnchor.constraint(equalTo: window.contentView!.leadingAnchor),
            root.trailingAnchor.constraint(equalTo: window.contentView!.trailingAnchor),
            root.topAnchor.constraint(equalTo: window.contentView!.topAnchor),
            root.bottomAnchor.constraint(equalTo: window.contentView!.bottomAnchor),
            progress.widthAnchor.constraint(equalTo: root.widthAnchor),
            reportScroll.widthAnchor.constraint(equalTo: root.widthAnchor),
            reportScroll.heightAnchor.constraint(greaterThanOrEqualToConstant: 230),
            reportsStack.widthAnchor.constraint(equalTo: reportScroll.contentView.widthAnchor, constant: -16)
        ])

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func button(_ title: String, _ action: Selector) -> NSButton {
        let result = NSButton(title: title, target: self, action: action)
        result.bezelStyle = .rounded
        return result
    }

    @objc private func chooseFiles() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = supportedExtensions.compactMap { UTType(filenameExtension: $0) }
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        if panel.runModal() == .OK { sources = panel.urls; updateSelection() }
    }

    @objc private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.folder]
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        if panel.runModal() == .OK { sources = panel.urls; updateSelection() }
    }

    private func filesToConvert() -> [URL] {
        var found = Set<URL>()
        for source in sources {
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: source.path, isDirectory: &isDirectory) else { continue }
            if isDirectory.boolValue {
                guard let enumerator = FileManager.default.enumerator(at: source, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles, .skipsPackageDescendants]) else { continue }
                for case let file as URL in enumerator where supportedExtensions.contains(file.pathExtension.lowercased()) {
                    if (try? file.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true { found.insert(file.standardizedFileURL) }
                }
            } else if supportedExtensions.contains(source.pathExtension.lowercased()) {
                found.insert(source.standardizedFileURL)
            }
        }
        return found.sorted { $0.path.localizedStandardCompare($1.path) == .orderedAscending }
    }

    private func updateSelection() {
        let files = filesToConvert()
        let summary = sources.map(\.path).joined(separator: "\n")
        sourceSummary.stringValue = summary + "\n\(files.count) supported audio file(s) found"
        convertButton.isEnabled = !files.isEmpty
    }

    private static var recoveryFolder: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appending(path: appName, directoryHint: .isDirectory)
            .appending(path: "Recovery", directoryHint: .isDirectory)
    }

    private static func bundledTool(_ name: String) throws -> URL {
        guard let url = Bundle.main.url(forResource: name, withExtension: nil) else {
            throw NSError(domain: appName, code: 1, userInfo: [NSLocalizedDescriptionKey: "The bundled \(name) tool is missing from this app."])
        }
        return url
    }

    private static func run(_ executable: URL, _ arguments: [String]) throws -> (Int32, String, String) {
        let process = Process()
        process.executableURL = executable
        process.arguments = arguments
        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = outputPipe
        try process.run()
        let output = outputPipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return (process.terminationStatus,
                String(data: output, encoding: .utf8) ?? "",
                "")
    }

    private static func probe(_ url: URL) -> (MediaInfo, Bool) {
        guard let probe = try? bundledTool("ffprobe"),
              let (status, output, _) = try? run(probe, ["-v", "error", "-show_streams", "-show_format", "-of", "json", url.path]),
              status == 0, let data = output.data(using: .utf8),
              let parsed = try? JSONDecoder().decode(ProbeResult.self, from: data) else { return (.unavailable, false) }
        let tags = (parsed.format?.tags ?? [:]).merging(parsed.streams?.first(where: { $0.codec_type == "audio" })?.tags ?? [:]) { current, _ in current }
        func tag(_ name: String, fallback: String) -> String {
            tags.first(where: { $0.key.caseInsensitiveCompare(name) == .orderedSame })?.value.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty ?? fallback
        }
        let hasArtwork = parsed.streams?.contains(where: { $0.disposition?.attached_pic == 1 }) ?? false
        var image: NSImage?
        if hasArtwork, let ffmpeg = try? bundledTool("ffmpeg") {
            let previewURL = FileManager.default.temporaryDirectory.appending(path: "audio-preview-\(UUID().uuidString).jpg")
            let extraction = try? run(ffmpeg, ["-hide_banner", "-loglevel", "error", "-y", "-i", url.path, "-map", "0:v:0", "-frames:v", "1", "-f", "image2", "-c:v", "mjpeg", previewURL.path])
            if extraction?.0 == 0 { image = NSImage(contentsOf: previewURL) }
            try? FileManager.default.removeItem(at: previewURL)
        }
        return (MediaInfo(title: tag("title", fallback: url.deletingPathExtension().lastPathComponent),
                          artist: tag("artist", fallback: "Unknown artist"),
                          album: tag("album", fallback: "Unknown album"),
                          hasArtwork: hasArtwork, artwork: image), true)
    }

    private static func convertToALAC(source: URL, destination: URL) throws {
        let ffmpeg = try bundledTool("ffmpeg")
        let result = try run(ffmpeg, ["-hide_banner", "-loglevel", "error", "-y", "-i", source.path,
                                      "-map", "0:a:0", "-map", "0:v?", "-map_metadata", "0", "-map_chapters", "0",
                                      "-c:a", "alac", "-c:v", "mjpeg", "-disposition:v", "attached_pic",
                                      "-movflags", "+faststart", destination.path])
        guard result.0 == 0 else {
            throw NSError(domain: appName, code: Int(result.0), userInfo: [NSLocalizedDescriptionKey: result.2.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty ?? result.1.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty ?? "FFmpeg could not convert this file."])
        }
    }

    private static func addToMusic(_ url: URL) throws -> URL? {
        let escapedPath = url.path
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
        let script = """
tell application "Music"
    set importedTrack to add (POSIX file "\(escapedPath)") to library playlist 1
    try
        return "IMPORTED_LOCATION:" & POSIX path of (location of importedTrack)
    on error
        return "IMPORTED_NO_LOCAL_LOCATION"
    end try
end tell
"""
        guard let appleScript = NSAppleScript(source: script) else {
            throw NSError(domain: appName, code: 3, userInfo: [NSLocalizedDescriptionKey: "Could not prepare the Music import command."])
        }
        var scriptError: NSDictionary?
        let result = appleScript.executeAndReturnError(&scriptError)
        if let scriptError {
            let message = scriptError[NSAppleScript.errorMessage] as? String ?? "Music did not confirm the imported track."
            throw NSError(domain: appName, code: 4, userInfo: [NSLocalizedDescriptionKey: message])
        }
        let response = result.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if response == "IMPORTED_NO_LOCAL_LOCATION" { return nil }
        let prefix = "IMPORTED_LOCATION:"
        guard response.hasPrefix(prefix) else {
            throw NSError(domain: appName, code: 2, userInfo: [NSLocalizedDescriptionKey: "Music did not return a recognizable import result."])
        }
        let location = String(response.dropFirst(prefix.count))
        guard !location.isEmpty else { return nil }
        return URL(fileURLWithPath: location).standardizedFileURL
    }

    @objc private func convert() {
        let files = filesToConvert()
        guard !files.isEmpty else { return }
        convertButton.isEnabled = false
        progress.isHidden = false
        progress.doubleValue = 0
        status.stringValue = "Converting and adding tracks to Music…"
        reportsStack.arrangedSubviews.forEach { reportsStack.removeArrangedSubview($0); $0.removeFromSuperview() }

        DispatchQueue.global(qos: .userInitiated).async {
            do { try FileManager.default.createDirectory(at: Self.recoveryFolder, withIntermediateDirectories: true) }
            catch {
                DispatchQueue.main.async { self.status.stringValue = "Could not create recovery folder: \(error.localizedDescription)"; self.convertButton.isEnabled = true }
                return
            }
            var completed = 0
            var failed = 0
            for (index, source) in files.enumerated() {
                var report = TrackReport(filename: source.lastPathComponent, info: .unavailable)
                let destination = Self.recoveryFolder.appending(path: source.deletingPathExtension().lastPathComponent + "-\(UUID().uuidString.prefix(8)).m4a")
                let partial = Self.recoveryFolder.appending(path: ".\(UUID().uuidString).partial.m4a")
                do {
                    do { try Self.convertToALAC(source: source, destination: partial) }
                    catch { try? FileManager.default.removeItem(at: partial); throw error }
                    try FileManager.default.moveItem(at: partial, to: destination)
                    report.conversion = "Converted to ALAC (.m4a)"
                    let (outputInfo, probeSucceeded) = Self.probe(destination)
                    report.info = outputInfo
                    if !probeSucceeded { report.info = Self.probe(source).0 }

                    do {
                        let musicLocation = try Self.addToMusic(destination)
                        report.importResult = "Added to Music" + (musicLocation.map { ": \($0.path)" } ?? " (Music did not report a local file location).")
                        if let musicLocation, musicLocation != destination.standardizedFileURL, FileManager.default.fileExists(atPath: musicLocation.path) {
                            do { try FileManager.default.removeItem(at: destination); report.outputCleanup = "Temporary ALAC removed after Music copied it." }
                            catch { report.outputCleanup = "Converted ALAC kept at \(destination.path); cleanup failed: \(error.localizedDescription)" }
                        } else if musicLocation == destination.standardizedFileURL {
                            report.outputCleanup = "Converted ALAC kept at \(destination.path); Music references this file, so removing it would break playback."
                        } else {
                            report.outputCleanup = "Converted ALAC kept at \(destination.path); Music did not report a file location, so it was kept to protect playback."
                        }
                        completed += 1
                    } catch {
                        report.importResult = "Music import failed."
                        report.outputCleanup = "Converted ALAC kept for retry at \(destination.path)"
                        report.sourceCleanup = "Original file kept in place."
                        report.error = error.localizedDescription
                        failed += 1
                    }
                } catch {
                    report.conversion = "Conversion failed."
                    report.outputCleanup = "No usable converted file was retained."
                    report.sourceCleanup = "Original file kept in place."
                    report.error = error.localizedDescription
                    try? FileManager.default.removeItem(at: partial)
                    failed += 1
                }

                DispatchQueue.main.async {
                    self.addReport(report)
                    self.progress.doubleValue = Double(index + 1) / Double(files.count)
                    self.status.stringValue = "Finished \(index + 1) of \(files.count)…"
                }
            }
            DispatchQueue.main.async {
                self.status.stringValue = "Finished: \(completed) added to Music, \(failed) failed. Review each track below."
                self.convertButton.isEnabled = true
            }
        }
    }

    private func addReport(_ report: TrackReport) {
        let card = NSStackView()
        card.orientation = .horizontal
        card.alignment = .top
        card.spacing = 12
        card.translatesAutoresizingMaskIntoConstraints = false

        let artwork = NSImageView()
        artwork.image = report.info.artwork ?? NSImage(systemSymbolName: "music.note", accessibilityDescription: "No artwork")
        artwork.imageScaling = .scaleProportionallyUpOrDown
        artwork.wantsLayer = true
        artwork.layer?.cornerRadius = 6
        artwork.layer?.backgroundColor = NSColor.quaternaryLabelColor.cgColor
        artwork.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([artwork.widthAnchor.constraint(equalToConstant: 64), artwork.heightAnchor.constraint(equalToConstant: 64)])
        card.addArrangedSubview(artwork)

        let details = NSStackView()
        details.orientation = .vertical
        details.alignment = .leading
        details.spacing = 4
        details.addArrangedSubview(textLabel("\(report.info.title) — \(report.info.artist)", bold: true))
        details.addArrangedSubview(textLabel("\(report.info.album) · \(report.filename)"))
        details.addArrangedSubview(textLabel(report.info.hasArtwork ? (report.info.artwork == nil ? "Artwork embedded (preview unavailable)" : "Artwork embedded and shown") : "No embedded artwork found"))
        details.addArrangedSubview(textLabel(report.conversion))
        details.addArrangedSubview(textLabel(report.importResult))
        details.addArrangedSubview(textLabel(report.outputCleanup))
        details.addArrangedSubview(textLabel(report.sourceCleanup))
        if let error = report.error { details.addArrangedSubview(textLabel("Error: \(error)", color: .systemRed)) }
        card.addArrangedSubview(details)

        let separator = NSBox()
        separator.boxType = .separator
        separator.translatesAutoresizingMaskIntoConstraints = false
        let container = NSStackView(views: [card, separator])
        container.orientation = .vertical
        container.alignment = .leading
        container.spacing = 8
        container.translatesAutoresizingMaskIntoConstraints = false
        reportsStack.addArrangedSubview(container)
        NSLayoutConstraint.activate([container.widthAnchor.constraint(equalTo: reportsStack.widthAnchor), separator.widthAnchor.constraint(equalTo: container.widthAnchor)])
    }

    private func textLabel(_ value: String, bold: Bool = false, color: NSColor = .secondaryLabelColor) -> NSTextField {
        let label = NSTextField(wrappingLabelWithString: value)
        label.textColor = color
        if bold { label.font = .boldSystemFont(ofSize: 13) }
        label.maximumNumberOfLines = 3
        return label
    }
}

private extension String {
    var nonEmpty: String? { isEmpty ? nil : self }
}
