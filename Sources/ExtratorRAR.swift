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
                .frame(minWidth: 440, minHeight: 540)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
        .defaultSize(width: 520, height: 640)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Botão direito numa pasta no Finder → Serviços → "Compactar com Extrator RAR"
        NSApp.servicesProvider = FinderService()
        NSUpdateDynamicServices()
    }

    // Arquivos e pastas abertos pelo Finder ("Abrir com", duplo clique ou soltos no ícone do Dock).
    func application(_ application: NSApplication, open urls: [URL]) {
        Extractor.shared.enqueue(urls, mode: .automatic)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

/// Recebe os itens enviados pelo menu de Serviços do Finder.
final class FinderService: NSObject {
    @objc func compressFiles(_ pboard: NSPasteboard, userData: String?, error: AutoreleasingUnsafeMutablePointer<NSString?>) {
        let urls = pboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL] ?? []
        Task { @MainActor in
            NSApp.activate()
            Extractor.shared.enqueue(urls, mode: .compress)
        }
    }
}

// MARK: - Formatos e tarefas

enum ArchiveFormat: String, CaseIterable, Identifiable {
    case zip, sevenZip = "7z", rar

    var id: String { rawValue }
    var fileExtension: String { rawValue }
    var title: String { rawValue.uppercased() }

    var summary: String {
        switch self {
        case .zip: "Abre em qualquer computador, sem instalar nada"
        case .sevenZip: "Arquivo menor; o destino precisa do 7-Zip ou similar"
        case .rar: "Formato do WinRAR; precisa do programa rar instalado"
        }
    }

    /// ZIP e 7Z usam o bsdtar do macOS. RAR é um formato fechado: só o programa oficial `rar` cria.
    var isAvailable: Bool { self != .rar || Extractor.findTool("rar") != nil }
}

struct Job: Identifiable {
    enum Kind { case extract, compress(ArchiveFormat) }
    enum Status { case waiting, running, done(URL), failed(String) }

    let id = UUID()
    let source: URL
    let kind: Kind
    var status: Status = .waiting
    var currentFile = ""
}

extension Job {
    var isFinished: Bool {
        switch status { case .done, .failed: true; default: false }
    }

    var isCompression: Bool {
        if case .compress = kind { return true }
        return false
    }
}

// MARK: - Extração e compactação

@MainActor
final class Extractor: ObservableObject {
    static let shared = Extractor()

    enum Mode { case automatic, extract, compress }

    @Published var jobs: [Job] = []
    @Published var openFolderWhenDone = true
    @Published var format: ArchiveFormat {
        didSet { UserDefaults.standard.set(format.rawValue, forKey: "format") }
    }
    let hasUnar = findTool("unar") != nil
    private var isRunning = false

    init() {
        format = UserDefaults.standard.string(forKey: "format").flatMap(ArchiveFormat.init) ?? .zip
    }

    static let archiveExtensions: Set<String> = ["rar", "zip", "7z", "tar", "gz", "tgz", "bz2", "tbz", "tbz2", "xz", "txz", "cab", "lzh", "lha", "cpio", "xar"]

    /// No modo automático, pastas e arquivos comuns são compactados e arquivos compactados são extraídos.
    func enqueue(_ urls: [URL], mode: Mode) {
        for url in urls where !jobs.contains(where: { $0.source == url && !$0.isFinished }) {
            let isFolder = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            let isArchive = Self.archiveExtensions.contains(url.pathExtension.lowercased())
            let shouldExtract = switch mode {
            case .extract: !isFolder
            case .compress: false
            case .automatic: !isFolder && isArchive
            }
            jobs.append(Job(source: url, kind: shouldExtract ? .extract : .compress(format)))
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
            let progress: @Sendable (String) -> Void = { name in
                Task { @MainActor in self.update(job.id) { $0.currentFile = name } }
            }
            let result = switch job.kind {
            case .extract: Self.extract(job.source, progress: progress)
            case .compress(let format): Self.compress(job.source, as: format, progress: progress)
            }
            await MainActor.run {
                self.update(job.id) { $0.status = result }
                if case .done(let output) = result, self.openFolderWhenDone {
                    NSWorkspace.shared.activateFileViewerSelecting([output])
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
    nonisolated static func extract(_ archive: URL, progress: @escaping @Sendable (String) -> Void) -> Job.Status {
        var name = archive.deletingPathExtension().lastPathComponent
        // "filme.part1.rar" -> "filme"
        if let range = name.range(of: #"\.part0*1$"#, options: [.regularExpression, .caseInsensitive]) {
            name.removeSubrange(range)
        }
        let destination = uniqueURL(in: archive.deletingLastPathComponent(), name: name)
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
        var message = errorMessage(result)
        if findTool("unar") == nil {
            message += "\n\nDica: para RAR com senha ou dividido em partes, instale o unar no Terminal:\nbrew install unar"
        }
        return .failed(message)
    }

    /// Compacta uma pasta (ou arquivo) num arquivo ao lado dela: "Fotos" -> "Fotos.zip".
    nonisolated static func compress(_ source: URL, as format: ArchiveFormat, progress: @escaping @Sendable (String) -> Void) -> Job.Status {
        let parent = source.deletingLastPathComponent()
        let isFolder = (try? source.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
        let baseName = isFolder ? source.lastPathComponent : source.deletingPathExtension().lastPathComponent
        let destination = uniqueURL(in: parent, name: baseName, extension: format.fileExtension)

        let result: (status: Int32, output: String)
        switch format {
        case .zip, .sevenZip:
            // -C entra na pasta de cima, assim o arquivo guarda "Fotos/..." e não o caminho inteiro.
            result = run("/usr/bin/bsdtar", ["-c", "--format", format == .zip ? "zip" : "7zip", "--exclude", ".DS_Store",
                                             "-v", "-f", destination.path, "-C", parent.path, source.lastPathComponent],
                         progress: progress)
        case .rar:
            guard let rar = findTool("rar") else {
                return .failed("Para criar .rar é preciso o programa oficial \"rar\" (da RARLAB, a empresa do WinRAR).\n\nEscolha ZIP, que abre em qualquer computador, ou veja no README como instalar o rar.")
            }
            // a = adicionar, -r = incluir subpastas, -ep1 = guardar só a partir de "Fotos/"
            result = run(rar, ["a", "-r", "-ep1", "-x*.DS_Store", destination.path, source.path], progress: progress)
        }

        if result.status == 0 { return .done(destination) }
        try? FileManager.default.removeItem(at: destination)
        return .failed(errorMessage(result))
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
            if let last = text.split(whereSeparator: \.isNewline).last {
                progress(fileName(fromLogLine: String(last)))
            }
        }

        do { try process.run() } catch { return (-1, error.localizedDescription) }
        process.waitUntilExit()
        pipe.fileHandleForReading.readabilityHandler = nil
        return (process.terminationStatus, collected.text)
    }

    /// bsdtar imprime "x arquivo" (extraindo) ou "a arquivo" (compactando); o rar imprime "Adding  arquivo  OK".
    nonisolated private static func fileName(fromLogLine line: String) -> String {
        var name = line.trimmingCharacters(in: .whitespaces)
        if name.hasPrefix("x ") || name.hasPrefix("a ") { name.removeFirst(2) }
        if name.hasPrefix("Adding") {
            name = String(name.dropFirst(6)).trimmingCharacters(in: .whitespaces)
            if name.hasSuffix("OK") { name = String(name.dropLast(2)).trimmingCharacters(in: .whitespaces) }
        }
        return name
    }

    nonisolated private static func errorMessage(_ result: (status: Int32, output: String)) -> String {
        let message = result.output.split(separator: "\n").suffix(3).joined(separator: "\n")
        return message.isEmpty ? "Erro desconhecido (código \(result.status))." : message
    }

    /// "Fotos" -> "Fotos 2" -> "Fotos 3"... até achar um nome livre.
    nonisolated private static func uniqueURL(in parent: URL, name: String, extension ext: String? = nil) -> URL {
        func url(_ base: String) -> URL {
            let file = parent.appendingPathComponent(base)
            return ext.map { file.appendingPathExtension($0) } ?? file
        }
        var candidate = url(name)
        var n = 2
        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = url("\(name) \(n)")
            n += 1
        }
        return candidate
    }

    nonisolated private static func removeIfEmpty(_ folder: URL) {
        if let items = try? FileManager.default.contentsOfDirectory(atPath: folder.path), items.isEmpty {
            try? FileManager.default.removeItem(at: folder)
        }
    }

    nonisolated static func findTool(_ name: String) -> String? {
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

// MARK: - Interface

extension Color {
    static let brand = Color(red: 0.42, green: 0.25, blue: 0.94)
    static let brandLight = Color(red: 0.56, green: 0.36, blue: 1.0)
}

enum Tab: String, CaseIterable {
    case extract = "Extrair"
    case compress = "Compactar"
}

struct ContentView: View {
    @ObservedObject var model: Extractor
    @State var tab: Tab = .extract
    @State private var isTargeted = false

    /// Com arquivos na lista, a área de soltar encolhe para dar espaço à lista.
    private var compact: Bool { !model.jobs.isEmpty }

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 24)
                .padding(.top, 34)  // espaço para os botões da janela (barra de título oculta)
                .padding(.bottom, 16)

            Picker("Modo", selection: $tab) {
                ForEach(Tab.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .controlSize(.large)
            .padding(.horizontal, 24)
            .padding(.bottom, 14)

            if tab == .compress {
                FormatPicker(format: $model.format)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 14)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            DropZone(tab: tab, compact: compact, isTargeted: isTargeted, action: chooseFiles)
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
        .animation(.easeInOut(duration: 0.25), value: tab)
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
                Text("Extraia e compacte arquivos, direto no seu Mac")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private var jobList: some View {
        VStack(spacing: 10) {
            HStack {
                Text("Atividade")
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
                if tab == .extract && !model.hasUnar {
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
                } else if tab == .compress {
                    ViewThatFits {
                        Label("Dica: botão direito na pasta → Serviços", systemImage: "cursorarrow.click.2")
                        Image(systemName: "cursorarrow.click.2")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .help("No Finder, clique com o botão direito numa pasta → Serviços → Compactar com Extrator RAR")
                }
            }
            .font(.callout)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
        }
        .background(.bar)
    }

    private var mode: Extractor.Mode { tab == .compress ? .compress : .automatic }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        let mode = mode
        for provider in providers {
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                if let url { Task { @MainActor in model.enqueue([url], mode: mode) } }
            }
        }
        return true
    }

    private func chooseFiles() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        if tab == .compress {
            panel.canChooseDirectories = true
            panel.message = "Escolha as pastas ou arquivos para compactar em .\(model.format.fileExtension)"
            panel.prompt = "Compactar"
        } else {
            panel.canChooseDirectories = false
            panel.message = "Escolha os arquivos para extrair"
            panel.prompt = "Extrair"
        }
        if panel.runModal() == .OK { model.enqueue(panel.urls, mode: tab == .compress ? .compress : .extract) }
    }
}

struct FormatPicker: View {
    @Binding var format: ArchiveFormat

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text("Formato")
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.secondary)
                ForEach(ArchiveFormat.allCases) { option in
                    FormatChip(format: option, selected: option == format) { format = option }
                }
                Spacer(minLength: 0)
            }
            Label(format.summary, systemImage: format.isAvailable ? "checkmark.circle" : "exclamationmark.circle")
                .font(.caption)
                .foregroundStyle(format.isAvailable ? Color.secondary : Color.orange)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct FormatChip: View {
    let format: ArchiveFormat
    let selected: Bool
    let action: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(".\(format.fileExtension)")
                    .font(.callout.weight(.semibold).monospaced())
                if !format.isAvailable {
                    Image(systemName: "lock.fill").font(.caption2)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .foregroundStyle(selected ? Color.white : (colorScheme == .dark ? Color.brandLight : Color.brand))
            .background(
                Capsule().fill(selected ? Color.brand : Color.brand.opacity(colorScheme == .dark ? 0.2 : 0.1))
            )
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .help(format.summary)
    }
}

struct DropZone: View {
    let tab: Tab
    let compact: Bool
    let isTargeted: Bool
    let action: () -> Void
    @State private var isHovering = false
    @Environment(\.colorScheme) private var colorScheme

    private var highlighted: Bool { isTargeted || isHovering }
    private var accent: Color { colorScheme == .dark ? .brandLight : .brand }

    private var title: String {
        if isTargeted { return tab == .compress ? "Solte para compactar" : "Solte aqui" }
        switch (tab, compact) {
        case (.extract, false): return "Arraste seus arquivos aqui"
        case (.extract, true): return "Arraste mais arquivos aqui"
        case (.compress, false): return "Arraste uma pasta aqui"
        case (.compress, true): return "Arraste mais pastas aqui"
        }
    }

    private var subtitle: String {
        tab == .compress ? "ou clique para escolher pastas e arquivos" : "ou clique para escolher no Finder"
    }

    private var icon: String {
        if isTargeted { return "arrow.down.to.line" }
        return tab == .compress ? "archivebox.fill" : "arrow.down.doc.fill"
    }

    var body: some View {
        Button(action: action) {
            Group {
                if compact {
                    HStack(spacing: 14) {
                        badge(size: 44, iconSize: 20)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(title).font(.headline)
                            Text(subtitle)
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
                            Text(title)
                                .font(.system(size: 19, weight: .semibold, design: .rounded))
                            Text(subtitle)
                                .foregroundStyle(.secondary)
                        }
                        if tab == .extract {
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
                        } else {
                            Text("O arquivo compactado é criado ao lado da pasta original")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                                .padding(.top, 2)
                        }
                    }
                    .padding(.horizontal, 16)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 240, maxHeight: .infinity)
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
            Image(systemName: icon)
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
                HStack(spacing: 6) {
                    Text(job.source.lastPathComponent)
                        .font(.body.weight(.medium))
                        .lineLimit(1)
                        .truncationMode(.middle)
                    kindBadge
                }
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

    private var kindBadge: some View {
        Text(kindLabel)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 1)
            .background(Capsule().fill(Color.secondary.opacity(0.12)))
            .fixedSize()
    }

    private var kindLabel: String {
        switch job.kind {
        case .extract: "extrair"
        case .compress(let format): "→ .\(format.fileExtension)"
        }
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
                Text(job.currentFile.isEmpty ? (job.isCompression ? "Compactando…" : "Extraindo…") : job.currentFile)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        case .done(let output):
            Label(output.lastPathComponent, systemImage: job.isCompression ? "doc.zipper" : "folder.fill")
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
        if case .done(let output) = job.status {
            Button {
                NSWorkspace.shared.activateFileViewerSelecting([output])
            } label: {
                Label(job.isCompression ? "Mostrar" : "Abrir", systemImage: "arrow.up.forward.app")
            }
            .controlSize(.small)
        }
    }
}
