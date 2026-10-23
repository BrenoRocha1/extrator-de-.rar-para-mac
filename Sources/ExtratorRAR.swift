import AppKit
import SwiftUI
import UniformTypeIdentifiers

// MARK: - App

#if !SNAPSHOT
@main
#endif
struct ExtratorRARApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Window("Extrator RAR", id: "main") {
            ContentView(model: Extractor.shared)
                .frame(minWidth: 440, minHeight: 500)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
        .defaultSize(width: 520, height: 600)
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
    let hasUnar = findTool("unar") != nil
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

extension Color {
    static let brand = Color(red: 0.42, green: 0.25, blue: 0.94)
    static let brandLight = Color(red: 0.56, green: 0.36, blue: 1.0)
}

struct ContentView: View {
    @ObservedObject var model: Extractor
    @State private var isTargeted = false

    /// Com arquivos na lista, a área de soltar encolhe para dar espaço à lista.
    private var compact: Bool { !model.jobs.isEmpty }

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 24)
                .padding(.top, 34)  // espaço para os botões da janela (barra de título oculta)
                .padding(.bottom, 18)

            DropZone(compact: compact, isTargeted: isTargeted, action: chooseFiles)
                .padding(.horizontal, 24)
                .onDrop(of: [.fileURL], isTargeted: $isTargeted, perform: handleDrop)

            if compact {
                jobList
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            Spacer(minLength: 0)
            footer
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.85), value: compact)
        .animation(.easeOut(duration: 0.15), value: isTargeted)
        .background(Color(nsColor: .windowBackgroundColor))
        .ignoresSafeArea(edges: .top)
    }

    private var header: some View {
        HStack(spacing: 14) {
            Image(nsImage: NSApp?.applicationIconImage ?? NSImage())
                .resizable()
                .frame(width: 52, height: 52)
            VStack(alignment: .leading, spacing: 2) {
                Text("Extrator RAR")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                Text("Abra .rar, .zip, .7z e mais, direto no seu Mac")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private var jobList: some View {
        VStack(spacing: 10) {
            HStack {
                Text("Extrações")
                    .font(.headline)
                Text("\(model.jobs.count)")
                    .font(.caption.weight(.semibold).monospacedDigit())
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.secondary.opacity(0.15)))
                Spacer()
                if model.jobs.contains(where: \.isFinished) {
                    Button("Limpar concluídos") {
                        withAnimation { model.clearFinished() }
                    }
                    .buttonStyle(.link)
                    .font(.callout)
                }
            }
            .padding(.horizontal, 24)

            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(model.jobs) { job in
                        JobRow(job: job)
                            .transition(.opacity.combined(with: .scale(scale: 0.97)))
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 12)
                .animation(.easeInOut(duration: 0.25), value: model.jobs.map(\.id))
            }
        }
        .padding(.top, 22)
    }

    private var footer: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 12) {
                Toggle("Abrir pasta ao terminar", isOn: $model.openFolderWhenDone)
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .fixedSize()
                Spacer(minLength: 0)
                if !model.hasUnar {
                    // Mostra a dica mais longa que couber na largura da janela.
                    ViewThatFits {
                        Label("Senha ou várias partes? brew install unar", systemImage: "info.circle")
                        Label("brew install unar", systemImage: "info.circle")
                        Image(systemName: "info.circle")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .help("Para abrir RAR com senha ou dividido em partes, rode no Terminal: brew install unar")
                }
            }
            .font(.callout)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
        }
        .background(.bar)
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                if let url { Task { @MainActor in model.enqueue([url]) } }
            }
        }
        return true
    }

    private func chooseFiles() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.message = "Escolha os arquivos para extrair"
        panel.prompt = "Extrair"
        if panel.runModal() == .OK { model.enqueue(panel.urls) }
    }
}

struct DropZone: View {
    let compact: Bool
    let isTargeted: Bool
    let action: () -> Void
    @State private var isHovering = false
    @Environment(\.colorScheme) private var colorScheme

    private var highlighted: Bool { isTargeted || isHovering }
    private var accent: Color { colorScheme == .dark ? .brandLight : .brand }

    var body: some View {
        Button(action: action) {
            Group {
                if compact {
                    HStack(spacing: 14) {
                        badge(size: 44, iconSize: 20)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(isTargeted ? "Solte para extrair" : "Arraste mais arquivos aqui")
                                .font(.headline)
                            Text("ou clique para escolher")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("⌘O")
                            .font(.callout.monospaced())
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal, 18)
                    .frame(height: 82)
                } else {
                    VStack(spacing: 14) {
                        badge(size: 84, iconSize: 36)
                        VStack(spacing: 4) {
                            Text(isTargeted ? "Solte para extrair" : "Arraste seus arquivos aqui")
                                .font(.system(size: 19, weight: .semibold, design: .rounded))
                            Text("ou clique para escolher no Finder")
                                .foregroundStyle(.secondary)
                        }
                        HStack(spacing: 6) {
                            ForEach(["RAR", "ZIP", "7Z", "TAR", "GZ"], id: \.self) { ext in
                                Text(ext)
                                    .font(.caption2.weight(.bold).monospaced())
                                    .foregroundStyle(accent)
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 3)
                                    .background(Capsule().fill(accent.opacity(colorScheme == .dark ? 0.2 : 0.12)))
                            }
                        }
                        .padding(.top, 2)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 260, maxHeight: .infinity)
                }
            }
            .frame(maxWidth: .infinity)
            .background(background)
            .contentShape(RoundedRectangle(cornerRadius: 18))
            .scaleEffect(isTargeted ? 1.015 : 1)
        }
        .buttonStyle(.plain)
        .keyboardShortcut("o")
        .onHover { isHovering = $0 }
        .padding(.bottom, compact ? 0 : 24)
    }

    private func badge(size: CGFloat, iconSize: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(LinearGradient(colors: [.brandLight, .brand], startPoint: .top, endPoint: .bottom))
                .shadow(color: Color.brand.opacity(0.35), radius: highlighted ? 10 : 5, y: 3)
            Image(systemName: isTargeted ? "arrow.down.to.line" : "arrow.down.doc.fill")
                .font(.system(size: iconSize, weight: .semibold))
                .foregroundStyle(.white)
                .contentTransition(.symbolEffect(.replace))
        }
        .frame(width: size, height: size)
        .scaleEffect(isTargeted ? 1.08 : 1)
    }

    private var background: some View {
        RoundedRectangle(cornerRadius: 18)
            .fill(accent.opacity(highlighted ? 0.12 : 0.06))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(accent.opacity(highlighted ? 0.8 : (colorScheme == .dark ? 0.5 : 0.35)),
                                  style: StrokeStyle(lineWidth: isTargeted ? 2 : 1.5, dash: isTargeted ? [] : [7, 5]))
            )
    }
}

struct JobRow: View {
    let job: Job

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            icon
            VStack(alignment: .leading, spacing: 4) {
                Text(job.archive.lastPathComponent)
                    .font(.body.weight(.medium))
                    .lineLimit(1)
                    .truncationMode(.middle)
                detail
            }
            Spacer(minLength: 8)
            trailing
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .controlBackgroundColor))
                .shadow(color: .black.opacity(0.06), radius: 2, y: 1)
        )
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(borderColor, lineWidth: 1))
    }

    private var tint: Color {
        switch job.status {
        case .waiting: .secondary
        case .running: .brand
        case .done: .green
        case .failed: .red
        }
    }

    private var borderColor: Color {
        if case .failed = job.status { return .red.opacity(0.35) }
        return Color.primary.opacity(0.07)
    }

    private var icon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 9).fill(tint.opacity(0.14))
            switch job.status {
            case .waiting: Image(systemName: "clock")
            case .running: ProgressView().controlSize(.small)
            case .done: Image(systemName: "checkmark")
            case .failed: Image(systemName: "exclamationmark.triangle.fill")
            }
        }
        .font(.system(size: 15, weight: .bold))
        .foregroundStyle(tint)
        .frame(width: 36, height: 36)
    }

    @ViewBuilder private var detail: some View {
        switch job.status {
        case .waiting:
            Text("Na fila").font(.caption).foregroundStyle(.secondary)
        case .running:
            VStack(alignment: .leading, spacing: 5) {
                ProgressView().progressViewStyle(.linear).tint(.brand)
                Text(job.currentFile.isEmpty ? "Extraindo…" : job.currentFile)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        case .done(let folder):
            Label(folder.lastPathComponent, systemImage: "folder.fill")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        case .failed(let message):
            Text(message)
                .font(.caption)
                .foregroundStyle(.red)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder private var trailing: some View {
        if case .done(let folder) = job.status {
            Button {
                NSWorkspace.shared.activateFileViewerSelecting([folder])
            } label: {
                Label("Abrir", systemImage: "arrow.up.forward.app")
            }
            .controlSize(.small)
        }
    }
}
