import AppKit
import SwiftUI
import UniformTypeIdentifiers

// MARK: - App

@main
struct ExtratorRARApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Window("Extrator RAR", id: "main") {
            ContentView(model: Extractor.shared)
                .frame(minWidth: 460, minHeight: 360)
        }
        .windowResizability(.contentSize)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    // Arquivos abertos pelo Finder ("Abrir com" ou duplo clique).
    func application(_ application: NSApplication, open urls: [URL]) {
        Extractor.shared.enqueue(urls)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

// MARK: - Extração

struct Job: Identifiable {
    enum Status { case waiting, running, done(URL), failed(String) }
    let id = UUID()
    let archive: URL
    var status: Status = .waiting
    var currentFile = ""
}

@MainActor
final class Extractor: ObservableObject {
    static let shared = Extractor()

    @Published var jobs: [Job] = []
    @Published var openFolderWhenDone = true
    private var isRunning = false

    func enqueue(_ urls: [URL]) {
        for url in urls where !jobs.contains(where: { $0.archive == url && !$0.isFinished }) {
            jobs.append(Job(archive: url))
        }
        runNext()
    }

    func clearFinished() {
        jobs.removeAll { $0.isFinished }
    }

    private func runNext() {
        guard !isRunning, let index = jobs.firstIndex(where: { if case .waiting = $0.status { true } else { false } }) else { return }
        isRunning = true
        jobs[index].status = .running
        let job = jobs[index]

        Task.detached {
            let result = await Self.extract(job.archive) { name in
                Task { @MainActor in self.update(job.id) { $0.currentFile = name } }
            }
            await MainActor.run {
                self.update(job.id) { $0.status = result }
                if case .done(let folder) = result, self.openFolderWhenDone {
                    NSWorkspace.shared.activateFileViewerSelecting([folder])
                }
                self.isRunning = false
                self.runNext()
            }
        }
    }

    private func update(_ id: UUID, _ change: (inout Job) -> Void) {
        if let i = jobs.firstIndex(where: { $0.id == id }) { change(&jobs[i]) }
    }

    /// Extrai para uma pasta ao lado do arquivo, com o mesmo nome dele.
    nonisolated static func extract(_ archive: URL, progress: @escaping @Sendable (String) -> Void) async -> Job.Status {
        let destination = uniqueFolder(for: archive)
        do {
            try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        } catch {
            return .failed("Não foi possível criar a pasta: \(error.localizedDescription)")
        }

        // Primeiro tenta o bsdtar do macOS (libarchive: RAR4, RAR5, ZIP, 7z, TAR...).
        var result = run("/usr/bin/bsdtar", ["-xvf", archive.path, "-C", destination.path], progress: progress)

        // RAR com senha ou dividido em partes: usa o unar, se estiver instalado.
        if result.status != 0, let unar = findTool("unar") {
            var args = ["-force-overwrite", "-no-directory", "-output-directory", destination.path, archive.path]
            result = run(unar, args, progress: progress)
            if result.status != 0, result.output.localizedCaseInsensitiveContains("password") {
                guard let password = askPassword(for: archive) else {
                    try? FileManager.default.removeItem(at: destination)
                    return .failed("Cancelado (arquivo protegido por senha).")
                }
                args.insert(contentsOf: ["-password", password], at: 0)
                result = run(unar, args, progress: progress)
            }
        }

        if result.status == 0 { return .done(destination) }

        removeIfEmpty(destination)
        var message = result.output.split(separator: "\n").suffix(3).joined(separator: "\n")
        if message.isEmpty { message = "Erro desconhecido (código \(result.status))." }
        if findTool("unar") == nil {
            message += "\n\nDica: para RAR com senha ou dividido em partes, instale o unar no Terminal:\nbrew install unar"
        }
        return .failed(message)
    }

    nonisolated private static func run(_ tool: String, _ args: [String], progress: @escaping @Sendable (String) -> Void) -> (status: Int32, output: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: tool)
        process.arguments = args
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        let collected = OutputBuffer()
        pipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
            collected.append(text)
            if let last = text.split(separator: "\n").last {
                // bsdtar -v imprime "x caminho/do/arquivo"
                progress(String(last.hasPrefix("x ") ? last.dropFirst(2) : last))
            }
        }

        do { try process.run() } catch { return (-1, error.localizedDescription) }
        process.waitUntilExit()
        pipe.fileHandleForReading.readabilityHandler = nil
        return (process.terminationStatus, collected.text)
    }

    nonisolated private static func uniqueFolder(for archive: URL) -> URL {
        var name = archive.deletingPathExtension().lastPathComponent
        // "filme.part1.rar" -> "filme"
        if let range = name.range(of: #"\.part0*1$"#, options: [.regularExpression, .caseInsensitive]) {
            name.removeSubrange(range)
        }
        let parent = archive.deletingLastPathComponent()
        var candidate = parent.appendingPathComponent(name)
        var n = 2
        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = parent.appendingPathComponent("\(name) \(n)")
            n += 1
        }
        return candidate
    }

    nonisolated private static func removeIfEmpty(_ folder: URL) {
        if let items = try? FileManager.default.contentsOfDirectory(atPath: folder.path), items.isEmpty {
            try? FileManager.default.removeItem(at: folder)
        }
    }

    nonisolated private static func findTool(_ name: String) -> String? {
        ["/opt/homebrew/bin", "/usr/local/bin"]
            .map { "\($0)/\(name)" }
            .first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    nonisolated private static func askPassword(for archive: URL) -> String? {
        DispatchQueue.main.sync {
            let alert = NSAlert()
            alert.messageText = "Senha necessária"
            alert.informativeText = "\"\(archive.lastPathComponent)\" está protegido por senha."
            let field = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 240, height: 24))
            alert.accessoryView = field
            alert.addButton(withTitle: "Extrair")
            alert.addButton(withTitle: "Cancelar")
            alert.window.initialFirstResponder = field
            return alert.runModal() == .alertFirstButtonReturn ? field.stringValue : nil
        }
    }
}

final class OutputBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private var storage = ""
    func append(_ s: String) { lock.lock(); storage += s; lock.unlock() }
    var text: String { lock.lock(); defer { lock.unlock() }; return storage }
}

extension Job {
    var isFinished: Bool {
        switch status { case .done, .failed: true; default: false }
    }
}

// MARK: - Interface

struct ContentView: View {
    @ObservedObject var model: Extractor
    @State private var isTargeted = false

    var body: some View {
        VStack(spacing: 16) {
            dropZone
            if !model.jobs.isEmpty { jobList }
            HStack {
                Toggle("Abrir pasta ao terminar", isOn: $model.openFolderWhenDone)
                Spacer()
                if model.jobs.contains(where: \.isFinished) {
                    Button("Limpar lista") { model.clearFinished() }
                }
            }
            .font(.callout)
        }
        .padding(20)
    }

    private var dropZone: some View {
        VStack(spacing: 10) {
            Image(systemName: "archivebox")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(isTargeted ? Color.accentColor : .secondary)
            Text("Arraste arquivos .rar aqui")
                .font(.title3.weight(.medium))
            Text("Também funciona com .zip, .7z, .tar, .gz…")
                .font(.callout)
                .foregroundStyle(.secondary)
            Button("Escolher arquivo…", action: chooseFiles)
                .keyboardShortcut("o")
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, minHeight: 190)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [8, 6]))
                .foregroundStyle(isTargeted ? Color.accentColor : Color.secondary.opacity(0.4))
                .background(RoundedRectangle(cornerRadius: 14).fill(isTargeted ? Color.accentColor.opacity(0.08) : .clear))
        )
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
            for provider in providers {
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    if let url { Task { @MainActor in model.enqueue([url]) } }
                }
            }
            return true
        }
    }

    private var jobList: some View {
        ScrollView {
            VStack(spacing: 8) {
                ForEach(model.jobs) { job in JobRow(job: job) }
            }
        }
        .frame(maxHeight: 220)
    }

    private func chooseFiles() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        if panel.runModal() == .OK { model.enqueue(panel.urls) }
    }
}

struct JobRow: View {
    let job: Job

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            icon.frame(width: 20)
            VStack(alignment: .leading, spacing: 3) {
                Text(job.archive.lastPathComponent).fontWeight(.medium).lineLimit(1)
                detail.font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if case .done(let folder) = job.status {
                Button("Mostrar") { NSWorkspace.shared.activateFileViewerSelecting([folder]) }
                    .controlSize(.small)
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.08)))
    }

    @ViewBuilder private var icon: some View {
        switch job.status {
        case .waiting: Image(systemName: "clock").foregroundStyle(.secondary)
        case .running: ProgressView().controlSize(.small)
        case .done: Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
        case .failed: Image(systemName: "xmark.octagon.fill").foregroundStyle(.red)
        }
    }

    @ViewBuilder private var detail: some View {
        switch job.status {
        case .waiting: Text("Na fila")
        case .running: Text(job.currentFile.isEmpty ? "Extraindo…" : job.currentFile).lineLimit(1).truncationMode(.middle)
        case .done(let folder): Text("Extraído em \(folder.lastPathComponent)")
        case .failed(let message): Text(message).textSelection(.enabled)
        }
    }
}
