<p align="center">
  <img src="assets/logo.png" width="160" alt="Logo do Extrator RAR">
</p>

<h1 align="center">Extrator RAR para macOS</h1>

<p align="center">
  Abra arquivos <code>.rar</code> e compacte suas pastas no Mac, sem WinRAR: arraste, solte e pronto.<br>
  <img src="https://img.shields.io/badge/macOS-14%2B-F2A600" alt="macOS 14+">
  <img src="https://img.shields.io/badge/Swift-SwiftUI-orange" alt="Swift">
</p>

<p align="center">
  <a href="https://github.com/BrenoRocha1/extrator-de-.rar-para-mac/releases/latest/download/Extrator-RAR.dmg">
    <img src="https://img.shields.io/badge/Baixar%20para%20Mac-.dmg-F2A600?style=for-the-badge&logo=apple&logoColor=white" alt="Baixar para Mac">
  </a>
</p>

O macOS não vem com o WinRAR e não abre arquivos `.rar` sozinho. Este projeto é um app nativo, pequeno e gratuito, que resolve isso **sem precisar instalar mais nada**:

- **Extrair:** arraste um `.rar` (ou `.zip`, `.7z`, `.tar`, `.gz`…) para a janela e ele é aberto. Funciona também com arquivos **protegidos por senha** e **divididos em partes**.
- **Compactar:** arraste uma pasta e ela vira um `.zip`, `.7z` ou `.rar`, com **senha** e **dividida em partes** se você quiser. Também dá para fazer pelo botão direito do mouse, direto no Finder.

<p align="center">
  <img src="assets/tela-inicial.png" width="270" alt="Aba Extrair">
  <img src="assets/tela-compactar.png" width="270" alt="Aba Compactar com senha e partes">
  <img src="assets/tela-extracoes.png" width="270" alt="Lista de atividade">
</p>

---

## Funcionalidades

### Extrair

- **Arrastar e soltar**: solte um ou vários arquivos na janela.
- **Clique para escolher** (ou `⌘O`): clicar na área de soltar abre uma janela de seleção de arquivos.
- **Arquivos com senha**: o app pergunta a senha numa janela. Se a senha estiver errada, ele avisa e deixa tentar de novo.
- **Arquivos divididos em partes** (`filme.part1.rar`, `filme.part2.rar`… ou `fotos.7z.001`, `fotos.7z.002`…): solte **qualquer uma** das partes, e o app encontra a primeira sozinho. Basta que todas as partes estejam na mesma pasta.
- **Sem pasta duplicada**: se o arquivo tem uma única pasta dentro (por exemplo `Fotos/`), ela vai direto para o lado do arquivo, e não para `Fotos/Fotos/`. Se tem um único arquivo dentro, o arquivo aparece direto.
- **Integração com o Finder**: o app aparece em *Abrir com* quando você clica com o botão direito num `.rar`.
- **Fila de tarefas**: os arquivos são processados um de cada vez, e cada um mostra seu status (na fila, trabalhando, concluído ou erro).
- **Progresso ao vivo**: mostra o nome do arquivo que está sendo extraído naquele momento.
- **Nunca sobrescreve nada**: se já existir uma pasta com o mesmo nome, o app cria `nome 2`, `nome 3` e assim por diante.
- **Abre a pasta no Finder ao terminar** (dá para desligar na janela).

### Ajuda

- **Boas-vindas na primeira abertura**: uma tela rápida explica como extrair, como compactar e como avisar de problemas. Ela aparece só uma vez.
- **Reportar problema**: o botão no rodapé da janela (ou o menu **Ajuda → Reportar um problema…**) abre um e-mail já preenchido com a versão do app, a versão do macOS e o tipo de Mac, o que ajuda a corrigir o problema mais rápido.

### Compactar

- **Transforme uma pasta em arquivo compactado**: arraste a pasta para a aba **Compactar** e escolha o formato.
- **Três formatos, todos sem instalar nada**:

  | Formato | Quando usar | Senha | Partes |
  |---|---|---|---|
  | `.zip` (padrão) | Para mandar para qualquer pessoa: abre em Mac, Windows e celular | Sim, AES-256 | Sim |
  | `.7z` | Para ocupar menos espaço | Sim, AES-256, esconde até os nomes dos arquivos | Sim |
  | `.rar` | Quando alguém pede especificamente um `.rar` | Com o `rar` oficial ([veja abaixo](#opcional-rar-comprimido-com-senha-ou-em-partes)) | Com o `rar` oficial |

- **Proteger com senha**: marque a opção e digite a senha. A senha nunca é salva pelo app.
- **Dividir em partes**: para mandar por e-mail (25 MB), gravar em CD (700 MB), caber num pendrive antigo (4 GB) ou outro tamanho da lista.
- **Botão direito no Finder**: clique com o botão direito numa pasta → **Serviços** → **Compactar com Extrator RAR**. Usa as mesmas opções da aba Compactar.
- **Arquivo criado ao lado da pasta**: `Fotos` vira `Fotos.zip` (ou `Fotos.zip.001`, `Fotos.zip.002`… quando dividido), na mesma pasta, sem sobrescrever nada.
- **Sem lixo do Mac**: os arquivos ocultos `.DS_Store` e a pasta `__MACOSX` não entram no arquivo, então ele fica limpo para quem usa Windows.
- **Lembra o último formato** e o tamanho das partes.

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
3. **Arraste o Extrator RAR para a pasta Aplicativos**, dentro dessa mesma janela. Se já tiver uma versão anterior, pode substituir.
4. **Abra o app pela primeira vez** (veja o aviso abaixo).
5. Pronto. Pode ejetar o "Extrator RAR" que apareceu na barra lateral do Finder e apagar o `.dmg`.

#### Aviso na primeira vez que abrir

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

2. Baixe o código e compile. Na primeira vez, o `build.sh` baixa o 7-Zip (cerca de 2 MB) do repositório oficial e confere a assinatura SHA-256 do arquivo antes de usar:

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

### (Opcional) `.rar` comprimido, com senha ou em partes

**Tudo o que está acima funciona sem instalar nada**, inclusive criar `.rar`. A única diferença é esta:

| | Sem o `rar` oficial | Com o `rar` oficial |
|---|---|---|
| Criar `.rar` | Sim, sem compressão (o arquivo fica do mesmo tamanho) | Sim, comprimido |
| `.rar` com senha | Não: use `.zip` ou `.7z` com senha | Sim |
| `.rar` em partes | Não: use `.zip` ou `.7z` em partes | Sim |

**Por quê?** O formato RAR pertence à RARLAB, a empresa do WinRAR. A estrutura do arquivo é documentada publicamente, e é com ela que o app cria `.rar` por conta própria. Já o algoritmo de compressão é fechado: só o programa oficial `rar` pode comprimir. O `.rar` sem compressão abre normalmente no WinRAR, no 7-Zip e em qualquer outro programa.

> **Na dúvida**, use `.zip` ou `.7z`: fazem tudo (senha e partes) sem instalar nada.

Para instalar o `rar` oficial:

1. Acesse [rarlab.com/download.htm](https://www.rarlab.com/download.htm) e baixe o **RAR for macOS** (escolha *ARM* se o seu Mac tem chip M1/M2/M3…, ou *x64* se ele é Intel).
2. Dê dois cliques no arquivo baixado (`rarmacos-….tar.gz`). Vai aparecer uma pasta `rar` em *Downloads*.
3. No Terminal, rode os comandos abaixo, um de cada vez (vai pedir a senha do Mac):

```bash
sudo mkdir -p /usr/local/bin
```

```bash
sudo install -m 755 ~/Downloads/rar/rar /usr/local/bin/rar
```

```bash
sudo xattr -d com.apple.quarantine /usr/local/bin/rar
```

4. Pronto: o app passa a usar o `rar` oficial sozinho, e o aviso laranja da aba Compactar some.

O `rar` é um programa *shareware* da RARLAB: dá para testar de graça, e a licença de uso contínuo é vendida por eles. O Homebrew deixou de distribuir o `rar` porque ele não passa na verificação de segurança do macOS (Gatekeeper), por isso a instalação é manual.

---

## Como usar

### Extrair um `.rar`

1. Abra o **Extrator RAR** (ele abre na aba **Extrair**).
2. Arraste um ou mais arquivos `.rar` para a área tracejada, ou clique nela para escolher os arquivos.
3. **Se o arquivo tiver senha**, uma janela vai pedir. Digite e clique em **Extrair**.
4. Espere o sinal de concluído (verde) aparecer na lista. O Finder abre mostrando o resultado.

**Arquivo dividido em partes?** Deixe todas as partes juntas na mesma pasta e solte qualquer uma delas.

**Pelo Finder:** clique com o botão direito no `.rar` → **Abrir com** → **Extrator RAR**.

**Para abrir todos os `.rar` com ele no duplo clique:** selecione um `.rar`, aperte `⌘I`, escolha **Extrator RAR** em *Abrir com* e clique em **Alterar Tudo…**.

### Transformar uma pasta em `.zip`, `.7z` ou `.rar`

**Pelo app:**

1. Abra o **Extrator RAR** e clique na aba **Compactar**.
2. Escolha o formato: **.zip**, **.7z** ou **.rar**. Na dúvida, deixe **.zip**.
3. (Opcional) Marque **Proteger com senha** e digite a senha. Clique no ícone de olho para conferir o que digitou.
4. (Opcional) Marque **Dividir em partes** e escolha o tamanho de cada parte.
5. Arraste a pasta para a área tracejada, ou clique nela para escolher.
6. Espere o sinal de concluído (verde). O arquivo novo aparece ao lado da pasta original, e o Finder mostra onde ele está.

**Pelo botão direito (mais rápido):**

1. No Finder, clique com o **botão direito** na pasta.
2. Vá em **Serviços** → **Compactar com Extrator RAR**. Em alguns Macs, essa opção aparece em **Ações Rápidas**.
3. O app abre sozinho e cria o arquivo com as opções da aba Compactar.

> Não achou a opção no menu? Abra o app uma vez depois de instalar, para o macOS registrar o serviço. Se ainda não aparecer, vá em **Ajustes do Sistema → Teclado → Atalhos de Teclado → Serviços → Arquivos e Pastas** e marque **Compactar com Extrator RAR**.

**Atalho:** arrastar uma **pasta** para a aba **Extrair** também funciona. O app percebe que é uma pasta e compacta em vez de extrair.

**Mandando para alguém no Windows?** `.zip` sem senha abre direto no Windows. `.zip` com senha usa criptografia AES-256, que o Windows abre com o 7-Zip ou o WinRAR (o descompactador que vem no Windows não abre AES).

### Encontrou um problema?

Clique em **Reportar problema**, no rodapé da janela, ou vá no menu **Ajuda → Reportar um problema…**. Vai abrir um e-mail para **brenohenrique91901@gmail.com** já com a versão do app e do macOS preenchidas: é só contar o que você estava fazendo e o que aconteceu.

Se o Mac não tiver um app de e-mail configurado, o endereço é copiado e o app avisa: basta colar no seu e-mail (Gmail, Outlook…).

---

## Como funciona, passo a passo

### 1. O arquivo chega ao app

O arquivo (ou pasta) pode chegar por quatro caminhos:

| Origem | Onde no código | Modo |
|---|---|---|
| Arrastar para a janela | `DropZone` → `.onDrop` → `ContentView.handleDrop` | Automático na aba Extrair, compactar na aba Compactar |
| Clique na área de soltar ou `⌘O` | `ContentView.chooseFiles()` → `NSOpenPanel` | Extrair ou compactar, conforme a aba |
| Finder ("Abrir com", duplo clique, soltar no ícone do Dock) | `AppDelegate.application(_:open:)` | Automático |
| Botão direito → Serviços → "Compactar com Extrator RAR" | `FinderService.compressFiles` | Compactar |

Todos levam ao mesmo método: `Extractor.shared.enqueue(urls, mode:)`. No modo **automático**, o app decide sozinho o que fazer com cada item:

- **Pasta** → compacta.
- **Arquivo compactado** (`.rar`, `.zip`, `.7z`, `.tar`, `.gz`…, e também partes como `.001` ou `.r00`) → extrai.
- **Qualquer outro arquivo** → compacta.

Na extração, `Archives.firstVolume(of:)` troca qualquer parte pela primeira: `filme.part3.rar` → `filme.part1.rar`, `fotos.7z.004` → `fotos.7z.001`, `velho.r05` → `velho.rar`. Assim, soltar várias partes de uma vez gera uma tarefa só.

O Finder só oferece o app em *Abrir com* porque o `Info.plist` declara, em `CFBundleDocumentTypes`, que o app sabe abrir arquivos compactados e pastas. Como o macOS não conhece o tipo `.rar` por padrão, o mesmo arquivo também declara esse tipo em `UTImportedTypeDeclarations`, com o identificador `com.rarlab.rar-archive`.

O item **Compactar com Extrator RAR** do menu de Serviços vem da chave `NSServices` do `Info.plist`. Ela diz ao macOS que o app recebe pastas e arquivos (`NSSendFileTypes`) pela mensagem `compressFiles`. Quando o app abre, o `AppDelegate` registra o `FinderService` como quem atende essa mensagem.

### 2. A fila

O `Extractor` guarda uma lista de `Job`s. Cada `Job` tem o item de origem, o tipo de tarefa (`extract`, ou `compress` com as opções escolhidas: formato, senha e tamanho das partes) e um status:

```
waiting (na fila) → running (trabalhando) → done (concluído) ou failed (erro)
```

O método `runNext()` pega o próximo job da fila e chama `Archives.extract` ou `Archives.compress`, conforme o tipo. Só um job roda por vez, o que evita vários processos competindo pelo disco. Quando um job termina, `runNext()` é chamado de novo para pegar o seguinte.

O trabalho roda em segundo plano (`Task.detached`), então a janela continua respondendo enquanto isso.

### 3. Os programas que fazem o trabalho

| Programa | De onde vem | Para que serve |
|---|---|---|
| **7-Zip** (`7zz`) | Vem **dentro do app** (`Contents/MacOS/7zz`) | Extrair quase tudo (inclusive RAR com senha e em partes) e criar `.zip`/`.7z` com senha e em partes |
| **`RarWriter`** | Código do próprio app (`Sources/RarWriter.swift`) | Criar `.rar` sem compressão quando o `rar` oficial não está instalado |
| **`bsdtar`** | Já vem no macOS (`/usr/bin/bsdtar`) | Plano B para formatos que o 7-Zip não conhece |
| **`rar`** (opcional) | Instalado pela pessoa, da RARLAB | Criar `.rar` comprimido, com senha ou em partes |

O enum `Tools` acha cada um: o 7-Zip pelo `Bundle.main` (dentro do app), e o `rar` em `/opt/homebrew/bin` ou `/usr/local/bin`.

### 4. A pasta de destino

O método `uniqueURL(in:name:extension:occupied:)` escolhe um nome livre, ao lado do item original:

- `~/Downloads/filme.rar` → `~/Downloads/filme/`
- `~/Downloads/filme.part1.rar` → `~/Downloads/filme/` (o sufixo `.part1` é removido)
- `~/Downloads/fotos.7z.001` → `~/Downloads/fotos/`
- Se `filme/` já existir, usa `filme 2/`, depois `filme 3/`, e assim por diante.
- Na compactação: `~/Documentos/Fotos/` → `~/Documentos/Fotos.zip`. Quando dividido, o app confere se `Fotos.zip.001` também está livre antes de escolher o nome.

### 5. A extração

O app roda o 7-Zip embutido:

```bash
7zz x -y -bb1 -bsp0 -p<senha> -o"pasta-destino" "arquivo.rar"
```

- `x`: extrai mantendo as pastas
- `-y`: responde "sim" a tudo, para nunca travar com uma pergunta
- `-bb1`: escreve o nome de cada arquivo extraído (o app usa isso para mostrar o progresso)
- `-bsp0`: esconde a porcentagem, que atrapalharia a leitura dos nomes
- `-o`: a pasta de destino

O método `run(_:_:in:progress:)` inicia o processo com `Process`, lê a saída linha por linha por um `Pipe` e envia o nome do arquivo atual para a interface. A entrada do processo é ligada ao "nada" (`FileHandle.nullDevice`), para que nenhum programa fique esperando alguém digitar.

Se o 7-Zip não reconhecer o formato, o app tenta o `bsdtar` do macOS como plano B.

### 6. A senha

Quando falta a senha, o 7-Zip tenta perguntar no teclado e trava. Para evitar isso, a **primeira tentativa vai com uma senha falsa aleatória** (`-p` + um UUID):

- Arquivo **sem senha**: o 7-Zip ignora a senha e extrai normalmente.
- Arquivo **com senha**: o 7-Zip responde *"Wrong password"*. O app mostra a janela pedindo a senha (`askPassword`) e tenta de novo.
- Senha **errada**: a janela volta com o título *"Senha incorreta"*, até a pessoa acertar ou cancelar.
- **Cancelar**: o app apaga a pasta de destino, que ficaria vazia ou com arquivos pela metade.

Isso funciona para `.rar` (com os dados cifrados ou até com os nomes cifrados), `.zip` e `.7z`.

### 7. Sem pasta duplicada

Depois de extrair, `unwrapSingleItem(_:)` olha o que tem dentro da pasta de destino. Se for **um único item**:

1. A pasta de destino é renomeada para um nome temporário oculto.
2. O item de dentro é movido para o lado do arquivo compactado, com um nome livre (`Fotos`, ou `Fotos 2` se já existir).
3. A pasta temporária, agora vazia, é apagada.

Assim `Fotos.zip` (com `Fotos/` dentro) vira `Fotos/`, e não `Fotos/Fotos/`. Se algo der errado no meio, a pasta volta a ser como era.

### 8. A compactação

O método `compress(_:options:progress:)` usa um programa diferente para cada formato.

**ZIP e 7Z**: o 7-Zip embutido, rodando dentro da pasta de cima (para o arquivo guardar `Fotos/...` e não o caminho inteiro do seu Mac):

```bash
7zz a -tzip -mx=5 -bb1 -bsp0 "-xr!.DS_Store" [-p<senha> -mem=AES256] [-v100m] "Fotos.zip" "Fotos"
```

- `a`: adiciona arquivos (cria o arquivo novo)
- `-tzip` ou `-t7z`: o formato. `-mx=5` (zip) e `-mx=7` (7z) são o nível de compressão
- `-xr!.DS_Store`: deixa de fora os arquivos ocultos que o Finder cria
- `-p<senha>`: protege com senha. No ZIP vem junto `-mem=AES256` (criptografia forte); no 7Z vem `-mhe=on`, que esconde até os nomes dos arquivos
- `-v100m`: divide em partes de 100 MB (`Fotos.zip.001`, `Fotos.zip.002`…)

**RAR com o `rar` oficial instalado**:

```bash
rar a -r -ep1 -y "-x*.DS_Store" [-hp<senha>] [-v100m] "Fotos.rar" "/caminho/até/Fotos"
```

- `-r`: inclui as subpastas; `-ep1`: guarda os caminhos a partir de `Fotos/`
- `-hp<senha>`: senha que esconde também os nomes dos arquivos
- `-v100m`: partes de 100 MB (`Fotos.part1.rar`, `Fotos.part2.rar`…)

**RAR sem o `rar` oficial**: o `RarWriter`, explicado abaixo.

Antes de começar, o app anota o que já existia na pasta. Se a compactação falhar, ele apaga só o que foi criado nessa tentativa (o arquivo pela metade ou as partes), sem encostar em mais nada.

### 9. O gravador de RAR próprio (`RarWriter`)

O RAR 5.0 tem a estrutura documentada pela própria RARLAB ([technote.htm](https://www.rarlab.com/technote.htm)). O `RarWriter` escreve essa estrutura usando o método **"armazenar"** (sem compressão), que não depende do algoritmo fechado:

1. **Assinatura** `Rar!` + `1A 07 01 00`, que identifica um RAR 5.0.
2. **Cabeçalho principal** (tipo 1).
3. Para cada pasta, um **cabeçalho de arquivo** (tipo 2) marcado como pasta. Para cada arquivo, um cabeçalho de arquivo com o tamanho, as permissões, a data de modificação e o **CRC32** do conteúdo, seguido do conteúdo em si.
4. **Cabeçalho de fim** (tipo 5).

Cada cabeçalho começa com o próprio CRC32, e os números usam o formato de tamanho variável do RAR (7 bits por byte). Os nomes ficam em UTF-8 na forma composta (NFC), que é a que o Windows usa. Atalhos (links simbólicos) e `.DS_Store` ficam de fora.

O resultado foi conferido com dois leitores independentes, o 7-Zip e o libarchive, e ambos extraem o conteúdo idêntico ao original.

### 10. O resultado

- **Deu certo**: o status vira `done` e aparece o botão **Abrir** (extração) ou **Mostrar** (compactação). Se a opção estiver ligada, o Finder abre mostrando o resultado.
- **Deu errado**: o app apaga o que ficou pela metade e mostra as linhas de erro do programa.

---

## Estrutura do projeto

```
.
├── Sources/
│   ├── ExtratorRAR.swift   # O app e a interface (SwiftUI)
│   ├── Engine.swift        # A fila, a extração e a compactação
│   ├── RarWriter.swift     # Gravador de arquivos .rar (RAR 5.0, sem compressão)
│   └── MakeIcon.swift      # Desenha a logo do app (ícone .icns e assets/logo.png)
├── assets/                 # Logo e capturas de tela usadas neste README
├── Info.plist              # Metadados do app, tipos de arquivo e o serviço do botão direito
├── build.sh                # Baixa o 7-Zip, compila e monta o "Extrator RAR.app"
├── release.sh              # Gera o instalador Extrator-RAR.dmg
└── README.md
```

A pasta `vendor/`, criada pelo `build.sh` com o 7-Zip baixado, não vai para o Git.

### `Sources/ExtratorRAR.swift` (app e interface)

| Parte | O que faz |
|---|---|
| `ExtratorRARApp` | Ponto de entrada do app (`@main`). Cria uma janela única. |
| `AppDelegate` | Recebe os arquivos abertos pelo Finder, registra o serviço do botão direito e fecha o app quando a janela é fechada. |
| `FinderService` | Atende o item "Compactar com Extrator RAR" do menu de Serviços do Finder. |
| `Support` | Monta o e-mail de "Reportar problema" (`mailto:` com assunto e texto prontos, versão do app, do macOS e tipo de Mac). Se não houver app de e-mail, copia o endereço. |
| `WelcomeView` | A tela de boas-vindas da primeira abertura. O app lembra que já mostrou guardando `welcomeShown` nas preferências. |
| `ContentView` | A janela: cabeçalho com a logo, abas Extrair/Compactar, área de soltar, lista de atividade e rodapé com as opções. |
| `FormatPicker` / `FormatChip` | A escolha de formato da aba Compactar, com uma explicação curta de cada um. |
| `CompressExtras` | As opções "Proteger com senha" (com botão para mostrar a senha) e "Dividir em partes". Ficam desligadas no `.rar` quando o `rar` oficial não está instalado. |
| `DropZone` | A área de soltar. Muda o texto e o ícone conforme a aba, fica grande quando a lista está vazia e vira uma barra compacta quando há tarefas. |
| `JobRow` | Um cartão da lista: ícone colorido pelo status, nome, etiqueta do tipo ("extrair" ou "→ .zip", com ícones de cadeado e de partes quando houver), barra de progresso ou erro, e botão "Abrir"/"Mostrar". |

### `Sources/Engine.swift` (o motor)

| Parte | O que faz |
|---|---|
| `Tools` | Encontra o 7-Zip embutido e o `rar` oficial (se instalado). |
| `ArchiveFormat` | Os formatos de compactação (ZIP, 7Z, RAR), com a descrição de cada um e se aceitam senha e partes neste Mac. |
| `CompressOptions` | Formato, senha e tamanho das partes de uma compactação. |
| `Job` | Uma tarefa da fila: o item de origem, o tipo (extrair ou compactar) e o status. |
| `Extractor` | A fila, as opções escolhidas na tela e a janela que pede a senha. |
| `Archives` | A extração (`extract`), a compactação (`compress`), a detecção de partes (`firstVolume`), os nomes livres (`uniqueURL`) e o "sem pasta duplicada" (`unwrapSingleItem`). |

### `build.sh`

1. Na primeira vez, baixa o **7-Zip 26.04** do repositório oficial do autor (`github.com/ip7z/7zip`), confere o **SHA-256** do arquivo e guarda em `vendor/`. Se o arquivo não conferir, o build para.
2. Compila os arquivos Swift com `swiftc -O -parse-as-library` duas vezes, uma para Apple Silicon (`arm64`) e outra para Intel (`x86_64`), e junta as duas com o `lipo`. O resultado é um app "universal" que roda em qualquer Mac.
3. Copia o `Info.plist`, o `7zz` (para `Contents/MacOS`) e a licença do 7-Zip (para `Contents/Resources`).
4. Roda o `MakeIcon.swift`, que desenha a logo (caixa com zíper e seta saindo, no amarelo das pastas do Windows) em vários tamanhos, e converte o resultado para `.icns` com o `iconutil`.
5. Assina o app inteiro, incluindo o 7-Zip, com uma assinatura local (`codesign --deep --sign -`), que o macOS exige para rodar apps em Macs com Apple Silicon.

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

- **`.rar` comprimido, com senha ou em partes** precisa do programa oficial `rar`, instalado à parte ([veja como](#opcional-rar-comprimido-com-senha-ou-em-partes)). Sem ele, o app cria `.rar` sem compressão. `.zip` e `.7z` fazem tudo sem instalar nada.
- O app não tem assinatura de desenvolvedor da Apple (que é paga), por isso o aviso na primeira vez que ele é aberto pelo instalador.

---

## Créditos e licenças

- **7-Zip** © Igor Pavlov ([7-zip.org](https://www.7-zip.org)), embutido no app sem modificações. Licença GNU LGPL, com partes sob BSD e a restrição de licença do unRAR (o código do unRAR não pode ser usado para recriar o algoritmo de compressão do RAR). O texto completo da licença vai dentro do app, em `Contents/Resources/7-Zip-License.txt`, e o código-fonte está em [github.com/ip7z/7zip](https://github.com/ip7z/7zip).
- **RAR** é marca registrada da RARLAB / Alexander Roshal. O `RarWriter` foi escrito a partir da especificação pública do formato e não usa código nem o algoritmo de compressão da RARLAB.
