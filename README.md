<p align="center">
  <img src="assets/logo.png" width="160" alt="Logo do Extrator RAR">
</p>

<h1 align="center">Extrator RAR para macOS</h1>

<p align="center">
  Abra arquivos <code>.rar</code> no Mac sem WinRAR: arraste, solte e pronto.<br>
  <img src="https://img.shields.io/badge/macOS-14%2B-6B40F0" alt="macOS 14+">
  <img src="https://img.shields.io/badge/Swift-SwiftUI-orange" alt="Swift">
</p>

<p align="center">
  <a href="https://github.com/BrenoRocha1/extrator-de-.rar-para-mac/releases/latest/download/Extrator-RAR.dmg">
    <img src="https://img.shields.io/badge/Baixar%20para%20Mac-.dmg-6B40F0?style=for-the-badge&logo=apple&logoColor=white" alt="Baixar para Mac">
  </a>
</p>

O macOS não vem com o WinRAR e não abre arquivos `.rar` sozinho. Este projeto é um app nativo, pequeno e gratuito, que resolve isso: você arrasta o `.rar` para a janela e ele é extraído.

Além de `.rar` (RAR4 e RAR5), o app também abre `.zip`, `.7z`, `.tar`, `.gz` e outros formatos compactados.

<p align="center">
  <img src="assets/tela-inicial.png" width="380" alt="Tela inicial do app">
  &nbsp;
  <img src="assets/tela-extracoes.png" width="380" alt="Lista de extrações">
</p>

---

## Funcionalidades

- **Arrastar e soltar**: solte um ou vários arquivos na janela.
- **Clique para escolher** (ou `⌘O`): clicar na área de soltar abre uma janela de seleção de arquivos.
- **Layout que se adapta**: sem arquivos, a área de soltar ocupa a janela; quando a extração começa, ela vira uma barra compacta e a lista ganha o espaço. A janela pode ser redimensionada e funciona no modo claro e no escuro.
- **Integração com o Finder**: o app aparece em *Abrir com* quando você clica com o botão direito num `.rar`.
- **Fila de extração**: os arquivos são extraídos um de cada vez, e cada um mostra seu status (na fila, extraindo, concluído ou erro).
- **Progresso ao vivo**: mostra o nome do arquivo que está sendo extraído naquele momento.
- **Pasta automática**: o conteúdo vai para uma pasta com o mesmo nome do arquivo, criada ao lado dele. Se a pasta já existir, cria `nome 2`, `nome 3` e assim por diante, sem sobrescrever nada.
- **Abre a pasta no Finder ao terminar** (dá para desligar na janela).
- **RAR com senha e RAR em várias partes**: funcionam se a ferramenta [`unar`](https://theunarchiver.com/command-line) estiver instalada. O app pede a senha numa janela.
- **Não depende de nada para o uso básico**: usa o `bsdtar`, que já vem instalado no macOS.

---

## Instalação

Existem duas formas de instalar. **Se você não mexe com programação, use a Opção 1.**

| | Opção 1: baixar o instalador | Opção 2: compilar o código |
|---|---|---|
| Para quem | Qualquer pessoa | Quem quer ver ou mudar o código |
| Precisa de Terminal? | Não | Sim |
| Precisa instalar algo antes? | Não | Xcode Command Line Tools |
| Tempo | 1 minuto | 5 minutos |

Requisito das duas: **macOS 14 (Sonoma) ou mais novo**, em Mac com Apple Silicon (M1, M2, M3…) ou com Intel.

### Opção 1: baixar o instalador (mais fácil)

1. **Baixe o instalador:** [**Extrator-RAR.dmg**](https://github.com/BrenoRocha1/extrator-de-.rar-para-mac/releases/latest/download/Extrator-RAR.dmg)
   (ou acesse a página de [Releases](https://github.com/BrenoRocha1/extrator-de-.rar-para-mac/releases) e clique em `Extrator-RAR.dmg`).
2. **Abra o arquivo baixado.** Ele fica na pasta *Downloads*. Uma janela vai aparecer com o app e um atalho para a pasta **Aplicativos**.
3. **Arraste o Extrator RAR para a pasta Aplicativos**, dentro dessa mesma janela.
4. **Abra o app pela primeira vez** (veja o aviso abaixo).
5. Pronto. Pode ejetar o "Extrator RAR" que apareceu na barra lateral do Finder e apagar o `.dmg`.

#### ⚠️ Aviso na primeira vez que abrir

O app é gratuito e não foi publicado na App Store, então o macOS mostra um aviso parecido com *"Não foi possível verificar o app"*. Isso é normal e só acontece uma vez. Para liberar:

**No macOS 15 (Sequoia) ou mais novo:**
1. Tente abrir o app e clique em **OK** (ou **Concluído**) no aviso.
2. Abra **Ajustes do Sistema** → **Privacidade e Segurança**.
3. Role até o fim da página e clique em **Abrir Mesmo Assim**, ao lado da mensagem sobre o Extrator RAR.
4. Confirme com sua senha do Mac e clique em **Abrir**.

**No macOS 14 (Sonoma):**
1. Na pasta Aplicativos, clique com o **botão direito** no Extrator RAR → **Abrir**.
2. No aviso, clique em **Abrir**.

<details>
<summary>Prefere usar o Terminal? Clique aqui</summary>

Este comando remove a marca de "baixado da internet" do app, e o aviso não aparece mais:

```bash
xattr -dr com.apple.quarantine "/Applications/Extrator RAR.app"
```

</details>

### Opção 2: compilar o código

1. Instale as ferramentas de desenvolvedor da Apple (traz o compilador `swiftc`):

```bash
xcode-select --install
```

2. Baixe o código e compile:

```bash
git clone https://github.com/BrenoRocha1/extrator-de-.rar-para-mac.git
cd extrator-de-.rar-para-mac
./build.sh
```

3. Copie o app gerado para a pasta Aplicativos:

```bash
ditto "Extrator RAR.app" "/Applications/Extrator RAR.app"
```

Como o app foi compilado no seu próprio Mac, o aviso da primeira abertura não aparece.

### (Opcional) Suporte a senha e a arquivos divididos em partes

Vale para as duas opções. Se você tem o [Homebrew](https://brew.sh), rode no Terminal:

```bash
brew install unar
```

---

## Como usar

1. Abra o **Extrator RAR**.
2. Arraste um ou mais arquivos `.rar` para a área tracejada, ou clique nela para escolher os arquivos.
3. Espere o ✓ verde aparecer na lista. A pasta com os arquivos extraídos abre no Finder.

**Pelo Finder:** clique com o botão direito no `.rar` → **Abrir com** → **Extrator RAR**.

**Para abrir todos os `.rar` com ele no duplo clique:** selecione um `.rar`, aperte `⌘I`, escolha **Extrator RAR** em *Abrir com* e clique em **Alterar Tudo…**.

---

## Como funciona, passo a passo

### 1. O arquivo chega ao app

O arquivo pode chegar por três caminhos:

| Origem | Onde no código |
|---|---|
| Arrastar para a janela | `DropZone` → `.onDrop` → `ContentView.handleDrop` |
| Clique na área de soltar ou `⌘O` | `ContentView.chooseFiles()` → `NSOpenPanel` |
| Finder ("Abrir com" / duplo clique) | `AppDelegate.application(_:open:)` |

Os três caminhos levam ao mesmo método: `Extractor.shared.enqueue(urls)`.

O Finder só oferece o app em *Abrir com* porque o `Info.plist` declara, em `CFBundleDocumentTypes`, que o app sabe abrir arquivos compactados. Como o macOS não conhece o tipo `.rar` por padrão, o mesmo arquivo também declara esse tipo em `UTImportedTypeDeclarations`, com o identificador `com.rarlab.rar-archive`.

### 2. A fila

O `Extractor` guarda uma lista de `Job`s. Cada `Job` tem um arquivo e um status:

```
waiting (na fila) → running (extraindo) → done (concluído) ou failed (erro)
```

O método `runNext()` pega o próximo job da fila e começa a extraí-lo. Só um job roda por vez, o que evita vários processos competindo pelo disco. Quando um job termina, `runNext()` é chamado de novo para pegar o seguinte.

A extração roda em segundo plano (`Task.detached`), então a janela continua respondendo enquanto o arquivo é extraído.

### 3. A pasta de destino

O método `uniqueFolder(for:)` decide onde os arquivos vão parar:

- `~/Downloads/filme.rar` → `~/Downloads/filme/`
- `~/Downloads/filme.part1.rar` → `~/Downloads/filme/` (o sufixo `.part1` é removido)
- Se `filme/` já existir, usa `filme 2/`, depois `filme 3/`, e assim por diante.

### 4. A extração com o `bsdtar` (padrão)

O macOS já vem com o `/usr/bin/bsdtar`, que usa a biblioteca **libarchive**. Essa biblioteca lê RAR4, RAR5, ZIP, 7z, TAR e outros formatos. O app executa:

```bash
/usr/bin/bsdtar -xvf "arquivo.rar" -C "pasta-destino"
```

- `-x`: extrai
- `-v`: escreve o nome de cada arquivo extraído (o app usa isso para mostrar o progresso)
- `-f`: indica o arquivo compactado
- `-C`: indica a pasta de destino

O método `run(_:_:progress:)` inicia o processo com `Process`, lê a saída linha por linha por um `Pipe` e envia a última linha para a interface. É por isso que o nome do arquivo atual aparece embaixo do nome do `.rar`.

### 5. Plano B: o `unar` (senha e arquivos em várias partes)

O `bsdtar` não abre RAR com senha nem RAR dividido em partes. Se ele falhar e o `unar` estiver instalado (o app procura em `/opt/homebrew/bin` e `/usr/local/bin`), o app tenta de novo com:

```bash
unar -force-overwrite -no-directory -output-directory "pasta-destino" "arquivo.rar"
```

Se a mensagem de erro mencionar `password`, o app mostra uma janela pedindo a senha (`askPassword`) e tenta mais uma vez com `-password`.

### 6. O resultado

- **Deu certo**: o status vira `done`, aparece o botão **Abrir** e, se a opção estiver ligada, a pasta abre no Finder.
- **Deu errado**: o app apaga a pasta de destino se ela tiver ficado vazia e mostra as últimas linhas do erro. Se o `unar` não estiver instalado, também sugere o `brew install unar`.

---

## Estrutura do projeto

```
.
├── Sources/
│   ├── ExtratorRAR.swift   # O app inteiro: interface (SwiftUI) + lógica de extração
│   └── MakeIcon.swift      # Desenha a logo do app (ícone .icns e assets/logo.png)
├── assets/                 # Logo e capturas de tela usadas neste README
├── Info.plist              # Metadados do app e tipos de arquivo que ele abre
├── build.sh                # Compila e monta o "Extrator RAR.app"
├── release.sh              # Gera o instalador Extrator-RAR.dmg
└── README.md
```

### `Sources/ExtratorRAR.swift`

| Parte | O que faz |
|---|---|
| `ExtratorRARApp` | Ponto de entrada do app (`@main`). Cria uma janela única. |
| `AppDelegate` | Recebe os arquivos abertos pelo Finder e fecha o app quando a janela é fechada. |
| `Job` | Representa um arquivo na fila e o status dele. |
| `Extractor` | O motor do app: fila, escolha da pasta, execução do `bsdtar`/`unar`, pedido de senha. |
| `OutputBuffer` | Junta a saída do processo de forma segura entre threads. |
| `ContentView` | A janela: cabeçalho com a logo, área de soltar, lista de extrações e rodapé com as opções. |
| `DropZone` | A área de soltar. Fica grande quando a lista está vazia e vira uma barra compacta quando há extrações. Reage ao passar o mouse e ao arrastar um arquivo por cima. |
| `JobRow` | Um cartão da lista: ícone colorido pelo status, nome, barra de progresso ou erro, e botão "Abrir". |

### `build.sh`

1. Apaga o `.app` anterior e cria a estrutura de pastas (`Contents/MacOS`, `Contents/Resources`).
2. Compila o Swift com `swiftc -O -parse-as-library` duas vezes, uma para Apple Silicon (`arm64`) e outra para Intel (`x86_64`), e junta as duas com o `lipo`. O resultado é um app "universal" que roda em qualquer Mac.
3. Copia o `Info.plist`.
4. Roda o `MakeIcon.swift`, que desenha a logo (caixa com zíper e seta saindo) em vários tamanhos, e converte o resultado para `.icns` com o `iconutil`.
5. Assina o app com uma assinatura local (`codesign --sign -`), que o macOS exige para rodar apps em Macs com Apple Silicon.

O projeto não usa Xcode nem `.xcodeproj`: basta o compilador de linha de comando.

### `release.sh` (para publicar uma nova versão)

Gera o `Extrator-RAR.dmg`, o instalador da Opção 1:

1. Roda o `build.sh` para gerar o app universal.
2. Monta uma pasta temporária com o app e um atalho chamado **Aplicativos** apontando para `/Applications`. É esse atalho que permite instalar só arrastando.
3. Cria a imagem de disco comprimida com o `hdiutil`.

Para publicar uma versão nova no GitHub:

```bash
./release.sh
gh release create v1.x Extrator-RAR.dmg --title "Extrator RAR v1.x" --notes "O que mudou"
```

O link de download do README (`releases/latest/download/Extrator-RAR.dmg`) sempre aponta para a versão mais recente, então ele não precisa ser alterado.

---

## Limitações

- RAR com senha e RAR em várias partes só funcionam com o `unar` instalado.
- O app só **extrai**; ele não cria arquivos `.rar`. O formato RAR é proprietário, e só o WinRAR/`rar` oficial consegue criar esses arquivos.
- O app não tem assinatura de desenvolvedor da Apple (que é paga), por isso o aviso na primeira vez que ele é aberto pelo instalador.
