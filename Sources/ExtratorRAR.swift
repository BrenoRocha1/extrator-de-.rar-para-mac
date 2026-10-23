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
                .frame(minWidth: 460, minHeight: 640)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
        .defaultSize(width: 540, height: 720)
        .commands {
            CommandGroup(replacing: .help) {
                Button("Reportar um problema…") { Support.reportProblem() }
            }
        }
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

/// Contato para avisar de problemas: abre um e-mail já preenchido com a versão do app e do macOS.
enum Support {
    static let email = "brenohenrique91901@gmail.com"

    static var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
    }

    static var reportURL: URL {
        #if arch(arm64)
        let chip = "Apple Silicon"
        #else
        let chip = "Intel"
        #endif
        let os = ProcessInfo.processInfo.operatingSystemVersion
        let body = """
        Olá! Encontrei um problema no Extrator RAR.

        O que eu estava fazendo:


        O que aconteceu:


        ---
        Extrator RAR \(appVersion) · macOS \(os.majorVersion).\(os.minorVersion).\(os.patchVersion) · \(chip)
        """
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = email
        components.queryItems = [
            URLQueryItem(name: "subject", value: "Problema no Extrator RAR \(appVersion)"),
            URLQueryItem(name: "body", value: body),
        ]
        return components.url!
    }

    @MainActor static func reportProblem() {
        if NSWorkspace.shared.open(reportURL) { return }
        // Sem app de e-mail configurado: copia o endereço e avisa.
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(email, forType: .string)
        let alert = NSAlert()
        alert.messageText = "E-mail copiado"
        alert.informativeText = "Não encontrei um app de e-mail configurado. O endereço \(email) foi copiado: cole no seu e-mail e conte o que aconteceu."
        alert.runModal()
    }
}

// MARK: - Interface

extension Color {
    /// Amarelo das pastas do Explorador de Arquivos do Windows (#FFC83D) e um tom mais forte (#F2A600).
    static let brand = Color(red: 1.0, green: 0.784, blue: 0.239)
    static let brandDeep = Color(red: 0.949, green: 0.651, blue: 0.0)
    /// Texto e ícones sobre o amarelo (marrom bem escuro, para ter contraste).
    static let onBrand = Color(red: 0.24, green: 0.17, blue: 0.0)

    /// Amarelo usado em textos e contornos: no modo claro, um âmbar escuro para ser legível no fundo branco.
    static func brandInk(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? .brand : Color(red: 0.6, green: 0.39, blue: 0.0)
    }
}

enum Tab: String, CaseIterable {
    case extract = "Extrair"
    case compress = "Compactar"
}

struct ContentView: View {
    @ObservedObject var model: Extractor
    @State var tab: Tab = .extract
    @State private var isTargeted = false
    @AppStorage("welcomeShown") private var welcomeShown = false
    @Environment(\.colorScheme) private var colorScheme

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
                VStack(alignment: .leading, spacing: 12) {
                    FormatPicker(format: $model.format)
                    CompressExtras(model: model)
                }
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
        .tint(Color.brandInk(colorScheme))  // links, caixas de seleção e chaves no tom do app
        // Boas-vindas só na primeira vez que o app abre.
        .sheet(isPresented: Binding(get: { !welcomeShown }, set: { if !$0 { welcomeShown = true } })) {
            WelcomeView { welcomeShown = true }
        }
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
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.brandInk(colorScheme))
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
                // Mostra a dica mais longa que couber na largura da janela.
                if tab == .extract {
                    ViewThatFits {
                        Label("Com senha ou em partes? Também abre", systemImage: "lock.open")
                        Image(systemName: "lock.open")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .help("Arquivos com senha: o app pergunta a senha. Arquivos em partes: solte qualquer uma das partes.")
                } else {
                    ViewThatFits {
                        Label("Dica: botão direito na pasta → Serviços", systemImage: "cursorarrow.click.2")
                        Image(systemName: "cursorarrow.click.2")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .help("No Finder, clique com o botão direito numa pasta → Serviços → Compactar com Extrator RAR")
                }
                Button {
                    Support.reportProblem()
                } label: {
                    Label("Reportar problema", systemImage: "envelope")
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.brandInk(colorScheme))
                .font(.caption)
                .fixedSize()
                .help("Abre um e-mail para \(Support.email) com a versão do app e do macOS já preenchidas")
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

/// Tela de boas-vindas mostrada só na primeira abertura.
struct WelcomeView: View {
    let onStart: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 18) {
            Image(nsImage: NSApp?.applicationIconImage ?? NSImage())
                .resizable()
                .frame(width: 84, height: 84)

            VStack(spacing: 6) {
                Text("Bem-vindo ao Extrator RAR")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                Text("Versão \(Support.appVersion)")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 12) {
                tip("arrow.down.doc.fill", "Para extrair", "Arraste um .rar, .zip ou .7z para a janela.")
                tip("archivebox.fill", "Para compactar", "Use a aba Compactar, ou clique com o botão direito numa pasta no Finder → Serviços.")
                tip("envelope.fill", "Achou algum problema?",
                    "Este app ainda é novo. Se algo der errado, clique em Reportar problema, no rodapé da janela, e me mande um e-mail. Eu corrijo o quanto antes.")
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.brand.opacity(colorScheme == .dark ? 0.1 : 0.16)))

            Text(Support.email)
                .font(.callout.monospaced())
                .foregroundStyle(.secondary)
                .textSelection(.enabled)

            Button(action: onStart) {
                Text("Começar")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.onBrand)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.brand))
                    .contentShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.defaultAction)
        }
        .padding(28)
        .frame(width: 420)
    }

    private func tip(_ icon: String, _ title: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.brandInk(colorScheme))
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.callout.weight(.semibold))
                Text(text)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
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
            Label(format.summary, systemImage: "info.circle")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// Senha e divisão em partes, na aba Compactar.
struct CompressExtras: View {
    @ObservedObject var model: Extractor
    @State private var showPassword = false

    private var enabled: Bool { model.format.supportsPasswordAndParts }

    /// Desmarcada enquanto o formato não aceita a opção, sem perder a escolha da pessoa.
    private func whenEnabled(_ value: Binding<Bool>) -> Binding<Bool> {
        Binding(get: { enabled && value.wrappedValue }, set: { value.wrappedValue = $0 })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Toggle(isOn: whenEnabled($model.usePassword)) {
                    Label("Proteger com senha", systemImage: "lock.fill")
                }
                .fixedSize()
                if model.usePassword && enabled {
                    Group {
                        if showPassword {
                            TextField("Senha", text: $model.password)
                        } else {
                            SecureField("Senha", text: $model.password)
                        }
                    }
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 200)
                    Button {
                        showPassword.toggle()
                    } label: {
                        Image(systemName: showPassword ? "eye.slash" : "eye")
                    }
                    .buttonStyle(.borderless)
                    .help(showPassword ? "Esconder a senha" : "Mostrar a senha")
                }
                Spacer(minLength: 0)
            }
            .frame(minHeight: 24)

            HStack(spacing: 10) {
                Toggle(isOn: whenEnabled($model.splitIntoParts)) {
                    Label("Dividir em partes", systemImage: "square.split.2x1")
                }
                .fixedSize()
                if model.splitIntoParts && enabled {
                    Picker("Tamanho de cada parte", selection: $model.volumeMB) {
                        ForEach(Extractor.volumeSizes, id: \.mb) { Text($0.label).tag($0.mb) }
                    }
                    .labelsHidden()
                    .fixedSize()
                }
                Spacer(minLength: 0)
            }
            .frame(minHeight: 24)

            if !enabled {
                Label("Senha e partes em .rar precisam do programa oficial rar. Em .zip e .7z funcionam sem instalar nada.",
                      systemImage: "exclamationmark.circle")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            } else if model.usePassword && model.format == .zip {
                Label("No Windows, .zip com senha abre pelo 7-Zip ou WinRAR (a criptografia é AES-256).",
                      systemImage: "info.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .toggleStyle(.checkbox)
        .disabled(!enabled)
        .animation(.easeInOut(duration: 0.2), value: model.usePassword)
        .animation(.easeInOut(duration: 0.2), value: model.splitIntoParts)
    }
}

struct FormatChip: View {
    let format: ArchiveFormat
    let selected: Bool
    let action: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: action) {
            Text(".\(format.fileExtension)")
                .font(.callout.weight(.semibold).monospaced())
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .foregroundStyle(selected ? Color.onBrand : Color.brandInk(colorScheme))
            .background(
                Capsule().fill(selected ? Color.brand : Color.brand.opacity(colorScheme == .dark ? 0.16 : 0.22))
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
    private var accent: Color { .brandInk(colorScheme) }

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
                                        .background(Capsule().fill(Color.brand.opacity(colorScheme == .dark ? 0.16 : 0.22)))
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
                    .frame(minHeight: tab == .compress ? 180 : 240, maxHeight: .infinity)
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
                .fill(LinearGradient(colors: [.brand, .brandDeep], startPoint: .top, endPoint: .bottom))
                .shadow(color: Color.brandDeep.opacity(0.4), radius: highlighted ? 10 : 5, y: 3)
            Image(systemName: icon)
                .font(.system(size: iconSize, weight: .semibold))
                .foregroundStyle(Color.onBrand)
                .contentTransition(.symbolEffect(.replace))
        }
        .frame(width: size, height: size)
        .scaleEffect(isTargeted ? 1.08 : 1)
    }

    private var background: some View {
        RoundedRectangle(cornerRadius: 18)
            .fill(Color.brand.opacity(highlighted ? (colorScheme == .dark ? 0.14 : 0.2) : (colorScheme == .dark ? 0.06 : 0.1)))
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
        HStack(spacing: 4) {
            Text(kindLabel)
            if case .compress(let options) = job.kind {
                if options.password != nil { Image(systemName: "lock.fill") }
                if options.volumeMB != nil { Image(systemName: "square.split.2x1") }
            }
        }
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
        case .compress(let options):
            "→ .\(options.format.fileExtension)"
        }
    }

    private var tint: Color {
        switch job.status {
        case .waiting: .secondary
        case .running: .brandDeep
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
                ProgressView().progressViewStyle(.linear).tint(.brandDeep)
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
