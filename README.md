# Extrator RAR para macOS

O macOS não vem com o WinRAR e não abre arquivos `.rar` sozinho. Este projeto é um app nativo, pequeno e gratuito, que resolve isso: você arrasta o `.rar` para a janela e ele é extraído.

Além de `.rar` (RAR4 e RAR5), o app também abre `.zip`, `.7z`, `.tar`, `.gz` e outros formatos compactados.

![macOS 14+](https://img.shields.io/badge/macOS-14%2B-blue) ![Swift](https://img.shields.io/badge/Swift-SwiftUI-orange)

---

## Funcionalidades

- **Arrastar e soltar**: solte um ou vários arquivos na janela.
- **Botão "Escolher arquivo…"** (ou `⌘O`) para escolher os arquivos numa janela de seleção.
- **Integração com o Finder**: o app aparece em *Abrir com* quando você clica com o botão direito num `.rar`.
- **Fila de extração**: os arquivos são extraídos um de cada vez, e cada um mostra seu status (na fila, extraindo, concluído ou erro).
- **Progresso ao vivo**: mostra o nome do arquivo que está sendo extraído naquele momento.
- **Pasta automática**: o conteúdo vai para uma pasta com o mesmo nome do arquivo, criada ao lado dele. Se a pasta já existir, cria `nome 2`, `nome 3` e assim por diante, sem sobrescrever nada.
- **Abre a pasta no Finder ao terminar** (dá para desligar na janela).
- **RAR com senha e RAR em várias partes**: funcionam se a ferramenta [`unar`](https://theunarchiver.com/command-line) estiver instalada. O app pede a senha numa janela.
- **Não depende de nada para o uso básico**: usa o `bsdtar`, que já vem instalado no macOS.

---

## Instalação

### Requisitos

- macOS 14 (Sonoma) ou mais novo
- Xcode Command Line Tools, que trazem o compilador `swiftc`. Para instalar:

```bash
xcode-select --install
```

### Compilar

```bash
git clone https://github.com/BrenoRocha1/extrator-de-.rar-para-mac.git
cd extrator-de-.rar-para-mac
./build.sh
```

O app gerado fica em `Extrator RAR.app`, dentro da pasta do projeto.

### Instalar na pasta Aplicativos

```bash
ditto "Extrator RAR.app" "/Applications/Extrator RAR.app"
```

> Na primeira vez que abrir o app, o macOS pode bloquear, porque ele não foi baixado da App Store. Se acontecer, clique com o botão direito no app → **Abrir** → **Abrir**. Depois disso ele abre normalmente.

### (Opcional) Suporte a senha e a arquivos divididos em partes

```bash
brew install unar
```

---

## Como usar

1. Abra o **Extrator RAR**.
2. Arraste um ou mais arquivos `.rar` para a área tracejada, ou clique em **Escolher arquivo…**.
3. Espere o ícone de concluído (✅). A pasta com os arquivos extraídos abre no Finder.

**Pelo Finder:** clique com o botão direito no `.rar` → **Abrir com** → **Extrator RAR**.

**Para abrir todos os `.rar` com ele no duplo clique:** selecione um `.rar`, aperte `⌘I`, escolha **Extrator RAR** em *Abrir com* e clique em **Alterar Tudo…**.

---

## Como funciona, passo a passo

### 1. O arquivo chega ao app

O arquivo pode chegar por três caminhos:

| Origem | Onde no código |
|---|---|
| Arrastar para a janela | `ContentView.dropZone` → `.onDrop` |
| Botão "Escolher arquivo…" | `ContentView.chooseFiles()` → `NSOpenPanel` |
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

- **Deu certo**: o status vira `done`, aparece o botão **Mostrar** e, se a opção estiver ligada, a pasta abre no Finder.
- **Deu errado**: o app apaga a pasta de destino se ela tiver ficado vazia e mostra as últimas linhas do erro. Se o `unar` não estiver instalado, também sugere o `brew install unar`.

---

## Estrutura do projeto

```
.
├── Sources/
│   ├── ExtratorRAR.swift   # O app inteiro: interface (SwiftUI) + lógica de extração
│   └── MakeIcon.swift      # Script que gera o ícone do app durante o build
├── Info.plist              # Metadados do app e tipos de arquivo que ele abre
├── build.sh                # Compila e monta o "Extrator RAR.app"
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
| `ContentView` | A janela: área de soltar arquivos, lista de jobs e opções. |
| `JobRow` | Uma linha da lista, com ícone, nome, progresso ou erro, e botão "Mostrar". |

### `build.sh`

1. Apaga o `.app` anterior e cria a estrutura de pastas (`Contents/MacOS`, `Contents/Resources`).
2. Compila o Swift com `swiftc -O -parse-as-library`.
3. Copia o `Info.plist`.
4. Roda o `MakeIcon.swift`, que desenha o ícone em vários tamanhos, e converte o resultado para `.icns` com o `iconutil`.
5. Assina o app com uma assinatura local (`codesign --sign -`), que o macOS exige para rodar apps em Macs com Apple Silicon.

O projeto não usa Xcode nem `.xcodeproj`: basta o compilador de linha de comando.

---

## Limitações

- RAR com senha e RAR em várias partes só funcionam com o `unar` instalado.
- O app só **extrai**; ele não cria arquivos `.rar`. O formato RAR é proprietário, e só o WinRAR/`rar` oficial consegue criar esses arquivos.
- O app não tem assinatura de desenvolvedor da Apple, por isso o aviso na primeira vez que ele é aberto.
