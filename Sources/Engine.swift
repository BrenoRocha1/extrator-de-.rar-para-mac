import AppKit

// MARK: - Ferramentas

/// Programas externos que o app usa. O 7-Zip (7zz) vem dentro do app; o `rar` oficial é opcional.
enum Tools {
    /// 7-Zip embutido em Contents/MacOS/7zz (ou instalado pelo Homebrew, em builds de desenvolvimento).
    static let sevenZip: String? = {
        if let bundled = Bundle.main.url(forAuxiliaryExecutable: "7zz")?.path,
           FileManager.default.isExecutableFile(atPath: bundled) {
            return bundled
        }
        return find("7zz")
    }()

    /// Programa oficial da RARLAB. Verificado a cada uso, porque a pessoa pode instalar com o app aberto.
    static var officialRar: String? { find("rar") }

    static func find(_ name: String) -> String? {
        ["/opt/homebrew/bin", "/usr/local/bin"]
            .map { "\($0)/\(name)" }
            .first { FileManager.default.isExecutableFile(atPath: $0) }
    }
}

// MARK: - Formatos e tarefas

enum ArchiveFormat: String, CaseIterable, Identifiable {
    case zip, sevenZip = "7z", rar

    var id: String { rawValue }
    var fileExtension: String { rawValue }

    var summary: String {
        switch self {
        case .zip: "Abre em qualquer computador, sem instalar nada"
        case .sevenZip: "Arquivo menor; quem recebe precisa do 7-Zip ou similar"
        case .rar: Tools.officialRar != nil
            ? "Formato do WinRAR, comprimido pelo rar oficial"
            : "Formato do WinRAR, sem compressão (com o rar oficial, fica comprimido)"
        }
    }

    /// Senha e partes em .rar só existem com o programa oficial; o gravador próprio só "armazena".
    var supportsPasswordAndParts: Bool { self != .rar || Tools.officialRar != nil }
}

struct CompressOptions: Equatable {
    var format: ArchiveFormat
    var password: String?
    var volumeMB: Int?
}

struct Job: Identifiable {
    enum Kind { case extract, compress(CompressOptions) }
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

// MARK: - Fila

@MainActor
final class Extractor: ObservableObject {
    static let shared = Extractor()

    enum Mode { case automatic, extract, compress }

    @Published var jobs: [Job] = []
    @Published var openFolderWhenDone = true
    @Published var format: ArchiveFormat {
        didSet { UserDefaults.standard.set(format.rawValue, forKey: "format") }
    }
    // A senha fica só na memória, nunca é salva.
    @Published var usePassword = false
    @Published var password = ""
    @Published var splitIntoParts: Bool {
        didSet { UserDefaults.standard.set(splitIntoParts, forKey: "splitIntoParts") }
    }
    @Published var volumeMB: Int {
        didSet { UserDefaults.standard.set(volumeMB, forKey: "volumeMB") }
    }
    private var isRunning = false

    static let volumeSizes: [(mb: Int, label: String)] = [
        (25, "25 MB (e-mail)"), (100, "100 MB"), (700, "700 MB (CD)"), (1000, "1 GB"), (4000, "4 GB (pendrive)"),
    ]

    init() {
        let defaults = UserDefaults.standard
        format = defaults.string(forKey: "format").flatMap(ArchiveFormat.init) ?? .zip
        splitIntoParts = defaults.bool(forKey: "splitIntoParts")
        let savedVolume = defaults.integer(forKey: "volumeMB")
        volumeMB = Self.volumeSizes.contains { $0.mb == savedVolume } ? savedVolume : 100
    }

    var compressOptions: CompressOptions {
        let canUseExtras = format.supportsPasswordAndParts
        return CompressOptions(format: format,
                               password: usePassword && canUseExtras ? password : nil,
                               volumeMB: splitIntoParts && canUseExtras ? volumeMB : nil)
    }

    /// No modo automático, pastas e arquivos comuns são compactados e arquivos compactados são extraídos.
    func enqueue(_ urls: [URL], mode: Mode) {
        let options = compressOptions
        for url in urls {
            let isFolder = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            let shouldExtract = switch mode {
            case .extract: !isFolder
            case .compress: false
            case .automatic: !isFolder && Archives.isArchive(url)
            }
            // Em arquivos divididos, qualquer parte aponta para a primeira; as outras são ignoradas.
            let source = shouldExtract ? Archives.firstVolume(of: url) : url
            if jobs.contains(where: { $0.source == source && !$0.isFinished }) { continue }

            if !shouldExtract, options.password == "" {
                jobs.append(Job(source: source, kind: .compress(options),
                                status: .failed("Digite a senha na aba Compactar, ou desligue \"Proteger com senha\".")))
                continue
            }
            jobs.append(Job(source: source, kind: shouldExtract ? .extract : .compress(options)))
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
            case .extract: Archives.extract(job.source, askPassword: Self.askPassword, progress: progress)
            case .compress(let options): Archives.compress(job.source, options: options, progress: progress)
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

    nonisolated private static func askPassword(for archive: URL, retry: Bool) -> String? {
        DispatchQueue.main.sync {
            let alert = NSAlert()
            alert.messageText = retry ? "Senha incorreta" : "Senha necessária"
            alert.informativeText = retry
                ? "A senha não abriu \"\(archive.lastPathComponent)\". Tente de novo."
                : "\"\(archive.lastPathComponent)\" está protegido por senha."
            let field = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 240, height: 24))
            alert.accessoryView = field
            alert.addButton(withTitle: "Extrair")
            alert.addButton(withTitle: "Cancelar")
            alert.window.initialFirstResponder = field
            return alert.runModal() == .alertFirstButtonReturn ? field.stringValue : nil
        }
    }
}

// MARK: - Extração e compactação

enum Archives {
    static let extensions: Set<String> = ["rar", "zip", "7z", "tar", "gz", "tgz", "bz2", "tbz", "tbz2", "xz", "txz",
                                          "cab", "lzh", "lha", "cpio", "xar", "iso", "zipx"]

    static func isArchive(_ url: URL) -> Bool {
        let name = url.lastPathComponent
        return extensions.contains(url.pathExtension.lowercased())
            || name.range(of: #"\.(\d{3}|r\d{2}|z\d{2})$"#, options: [.regularExpression, .caseInsensitive]) != nil
    }

    /// "filme.part3.rar" -> "filme.part1.rar", "fotos.7z.004" -> "fotos.7z.001", "velho.r05" -> "velho.rar".
    static func firstVolume(of url: URL) -> URL {
        let name = url.lastPathComponent
        let folder = url.deletingLastPathComponent()
        let candidates: [String?] = [
            name.replacingMatch(#"^(.*\.part)(\d+)(\.rar)$"#) { "\($0[1])\(String(repeating: "0", count: $0[2].count - 1))1\($0[3])" },
            name.replacingMatch(#"^(.*)\.\d{3}$"#) { "\($0[1]).001" },
            name.replacingMatch(#"^(.*)\.r\d{2}$"#) { "\($0[1]).rar" },
            name.replacingMatch(#"^(.*)\.z\d{2}$"#) { "\($0[1]).zip" },
        ]
        for case let candidate? in candidates where candidate != name {
            let first = folder.appendingPathComponent(candidate)
            if FileManager.default.fileExists(atPath: first.path) { return first }
        }
        return url
    }

    /// Nome da pasta de destino: "filme.part1.rar" -> "filme", "fotos.7z.001" -> "fotos", "x.tar.gz" -> "x".
    static func baseName(of archive: URL) -> String {
        var name = archive.lastPathComponent
        for pattern in [#"\.\d{3}$"#, #"\.part\d+\.rar$"#, #"\.[^.]+$"#, #"\.tar$"#] {
            if let range = name.range(of: pattern, options: [.regularExpression, .caseInsensitive]),
               range.lowerBound != name.startIndex {
                name.removeSubrange(range)
            }
        }
        return name
    }

    // MARK: Extrair

    typealias PasswordPrompt = (_ archive: URL, _ retry: Bool) -> String?

    /// Extrai para uma pasta ao lado do arquivo, com o mesmo nome dele.
    static func extract(_ archive: URL, askPassword: PasswordPrompt, progress: @escaping @Sendable (String) -> Void) -> Job.Status {
        let destination = uniqueURL(in: archive.deletingLastPathComponent(), name: baseName(of: archive))
        do {
            try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        } catch {
            return .failed("Não foi possível criar a pasta: \(error.localizedDescription)")
        }

        var result: ToolResult
        if let sevenZip = Tools.sevenZip {
            // Primeira tentativa com uma senha falsa aleatória: arquivos sem senha ignoram,
            // e os protegidos respondem "Wrong password" em vez de travar esperando o teclado.
            var password = UUID().uuidString
            var asked = false
            while true {
                result = run(sevenZip, ["x", "-y", "-bb1", "-bsp0", "-p" + password, "-o" + destination.path, archive.path],
                             progress: progress)
                let needsPassword = result.output.localizedCaseInsensitiveContains("wrong password")
                    || result.output.contains("Break signaled")
                guard result.status != 0, needsPassword else { break }
                guard let typed = askPassword(archive, asked) else {
                    try? FileManager.default.removeItem(at: destination)
                    return .failed("Cancelado (arquivo protegido por senha).")
                }
                password = typed
                asked = true
            }
            // Formato que o 7-Zip não conhece: tenta o bsdtar do macOS.
            if result.status != 0, !result.output.localizedCaseInsensitiveContains("password") {
                let fallback = run("/usr/bin/bsdtar", ["-xvf", archive.path, "-C", destination.path], progress: progress)
                if fallback.status == 0 { result = fallback }
            }
        } else {
            result = run("/usr/bin/bsdtar", ["-xvf", archive.path, "-C", destination.path], progress: progress)
        }

        if result.status == 0 { return .done(unwrapSingleItem(destination)) }
        try? FileManager.default.removeItem(at: destination)
        return .failed(errorMessage(result))
    }

    /// Se o arquivo tinha um único item dentro (por exemplo a pasta "Fotos/"), ele vai direto para
    /// o lado do arquivo compactado, em vez de ficar em "Fotos/Fotos/". Igual ao Utilitário de Arquivo do Mac.
    static func unwrapSingleItem(_ folder: URL) -> URL {
        let fm = FileManager.default
        guard let items = try? fm.contentsOfDirectory(atPath: folder.path).filter({ $0 != ".DS_Store" }),
              items.count == 1 else { return folder }
        let name = items[0]
        let parent = folder.deletingLastPathComponent()
        let temporary = parent.appendingPathComponent(".extrator-rar-\(UUID().uuidString)")
        do {
            try fm.moveItem(at: folder, to: temporary)
            let inner = temporary.appendingPathComponent(name)
            let isFolder = (try? inner.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            let target = isFolder || (name as NSString).pathExtension.isEmpty
                ? uniqueURL(in: parent, name: name)
                : uniqueURL(in: parent, name: (name as NSString).deletingPathExtension, extension: (name as NSString).pathExtension)
            try fm.moveItem(at: inner, to: target)
            try fm.removeItem(at: temporary)
            return target
        } catch {
            // Se algo der errado, devolve a pasta como estava.
            if fm.fileExists(atPath: temporary.path), !fm.fileExists(atPath: folder.path) {
                try? fm.moveItem(at: temporary, to: folder)
            }
            return folder
        }
    }

    // MARK: Compactar

    /// Compacta uma pasta (ou arquivo) num arquivo ao lado dela: "Fotos" -> "Fotos.zip".
    static func compress(_ source: URL, options: CompressOptions, progress: @escaping @Sendable (String) -> Void) -> Job.Status {
        let parent = source.deletingLastPathComponent()
        let isFolder = (try? source.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
        let baseName = isFolder ? source.lastPathComponent : source.deletingPathExtension().lastPathComponent
        let ext = options.format.fileExtension
        let officialRar = options.format == .rar ? Tools.officialRar : nil

        // Nomes que o resultado vai ocupar: "Fotos.zip", "Fotos.zip.001" (7-Zip) ou "Fotos.part1.rar" (rar).
        let destination = uniqueURL(in: parent, name: baseName, extension: ext) { base in
            [base, base + ".001", (base as NSString).deletingPathExtension + ".part1.rar"]
        }
        let before = Set((try? FileManager.default.contentsOfDirectory(atPath: parent.path)) ?? [])

        var result: ToolResult
        switch options.format {
        case .zip, .sevenZip:
            if let sevenZip = Tools.sevenZip {
                var args = ["a", options.format == .zip ? "-tzip" : "-t7z", options.format == .zip ? "-mx=5" : "-mx=7",
                            "-bb1", "-bsp0", "-xr!.DS_Store"]
                if let password = options.password {
                    // ZIP: criptografia AES-256. 7Z: AES-256 e também os nomes dos arquivos escondidos.
                    args += ["-p" + password, options.format == .zip ? "-mem=AES256" : "-mhe=on"]
                }
                if let volume = options.volumeMB { args.append("-v\(volume)m") }
                // Roda dentro da pasta de cima, assim o arquivo guarda "Fotos/..." e não o caminho inteiro.
                result = run(sevenZip, args + [destination.path, source.lastPathComponent], in: parent, progress: progress)
            } else {
                result = run("/usr/bin/bsdtar", ["-c", "--format", options.format == .zip ? "zip" : "7zip", "--exclude", ".DS_Store",
                                                 "-v", "-f", destination.path, "-C", parent.path, source.lastPathComponent],
                             progress: progress)
            }

        case .rar:
            if let rar = officialRar {
                // a = adicionar, -r = subpastas, -ep1 = caminhos a partir de "Fotos/", -hp = senha que esconde até os nomes
                var args = ["a", "-r", "-ep1", "-y", "-x*.DS_Store"]
                if let password = options.password { args.append("-hp" + password) }
                if let volume = options.volumeMB { args.append("-v\(volume)m") }
                result = run(rar, args + [destination.path, source.path], progress: progress)
            } else if options.password != nil || options.volumeMB != nil {
                return .failed("Senha e partes em .rar precisam do programa oficial rar. Use .zip ou .7z, que fazem isso sem instalar nada.")
            } else {
                do {
                    try RarWriter.create(at: destination, from: source, progress: progress)
                    result = ToolResult(status: 0, output: "")
                } catch {
                    result = ToolResult(status: 1, output: error.localizedDescription)
                }
            }
        }

        // Arquivos novos que apareceram ao lado da pasta (o .zip, ou as partes .001, .002...)
        let created = Set((try? FileManager.default.contentsOfDirectory(atPath: parent.path)) ?? []).subtracting(before)
            .filter { $0.hasPrefix(baseName) }
        if result.status == 0 {
            let first = [destination.lastPathComponent, destination.lastPathComponent + ".001",
                         destination.deletingPathExtension().lastPathComponent + ".part1.rar"]
                .first { created.contains($0) }
            return .done(first.map { parent.appendingPathComponent($0) } ?? destination)
        }
        for name in created { try? FileManager.default.removeItem(at: parent.appendingPathComponent(name)) }
        return .failed(errorMessage(result))
    }

    // MARK: Utilidades

    struct ToolResult {
        let status: Int32
        let output: String
    }

    private static func run(_ tool: String, _ args: [String], in directory: URL? = nil,
                            progress: @escaping @Sendable (String) -> Void) -> ToolResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: tool)
        process.arguments = args
        if let directory { process.currentDirectoryURL = directory }
        process.standardInput = FileHandle.nullDevice  // nenhum programa fica esperando o teclado
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        let collected = OutputBuffer()
        pipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
            collected.append(text)
            if let last = text.split(whereSeparator: \.isNewline).last {
                let name = fileName(fromLogLine: String(last))
                if !name.isEmpty { progress(name) }
            }
        }

        do { try process.run() } catch { return ToolResult(status: -1, output: error.localizedDescription) }
        process.waitUntilExit()
        pipe.fileHandleForReading.readabilityHandler = nil
        return ToolResult(status: process.terminationStatus, output: collected.text)
    }

    /// bsdtar: "x arquivo" / "a arquivo"; 7-Zip: "- arquivo" / "+ arquivo"; rar: "Adding  arquivo  OK".
    static func fileName(fromLogLine line: String) -> String {
        var name = line.trimmingCharacters(in: .whitespaces)
        for prefix in ["x ", "a ", "- ", "+ "] where name.hasPrefix(prefix) {
            return String(name.dropFirst(2))
        }
        if name.hasPrefix("Adding") {
            name = String(name.dropFirst(6)).trimmingCharacters(in: .whitespaces)
            if name.hasSuffix("OK") { name = String(name.dropLast(2)).trimmingCharacters(in: .whitespaces) }
            return name
        }
        return ""
    }

    private static func errorMessage(_ result: ToolResult) -> String {
        let lines = result.output.split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { $0.hasPrefix("ERROR") || $0.contains("rror") || $0.contains("Cannot") }
        let message = (lines.isEmpty ? Array(result.output.split(separator: "\n").suffix(3).map(String.init)) : Array(lines.prefix(3)))
            .joined(separator: "\n")
        return message.isEmpty ? "Erro desconhecido (código \(result.status))." : message
    }

    /// "Fotos" -> "Fotos 2" -> "Fotos 3"... até achar um nome livre.
    /// `occupied` lista os nomes que o resultado vai usar (por exemplo as partes .001).
    static func uniqueURL(in parent: URL, name: String, extension ext: String? = nil,
                          occupied: (String) -> [String] = { [$0] }) -> URL {
        func fileName(_ base: String) -> String { ext.map { "\(base).\($0)" } ?? base }
        var candidate = fileName(name)
        var n = 2
        while occupied(candidate).contains(where: { FileManager.default.fileExists(atPath: parent.appendingPathComponent($0).path) }) {
            candidate = fileName("\(name) \(n)")
            n += 1
        }
        return parent.appendingPathComponent(candidate)
    }
}

final class OutputBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private var storage = ""
    func append(_ s: String) { lock.lock(); storage += s; lock.unlock() }
    var text: String { lock.lock(); defer { lock.unlock() }; return storage }
}

private extension String {
    /// Se o texto bate com a expressão, devolve o resultado de `build` com os grupos capturados.
    func replacingMatch(_ pattern: String, _ build: ([String]) -> String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: self, range: NSRange(startIndex..., in: self)) else { return nil }
        let groups = (0..<match.numberOfRanges).map { i in
            Range(match.range(at: i), in: self).map { String(self[$0]) } ?? ""
        }
        return build(groups)
    }
}
