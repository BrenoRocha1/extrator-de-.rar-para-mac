import Foundation

/// Cria arquivos .rar no formato RAR 5.0, seguindo a especificação pública da RARLAB
/// (https://www.rarlab.com/technote.htm).
///
/// Os arquivos são guardados sem compressão (método "armazenar"): o algoritmo de compressão
/// do RAR é fechado, mas o formato do arquivo em si é documentado. O resultado abre normalmente
/// no WinRAR, no 7-Zip, no The Unarchiver e neste app. Para .rar comprimido, com senha ou em
/// partes, o app usa o programa oficial `rar` quando ele está instalado.
enum RarWriter {
    struct WriteError: LocalizedError {
        let errorDescription: String?
    }

    /// Compacta `source` (pasta ou arquivo) em `destination`. Os caminhos dentro do .rar
    /// começam pelo nome da pasta: "Fotos/praia.jpg".
    static func create(at destination: URL, from source: URL, progress: (String) -> Void) throws {
        let fm = FileManager.default
        let rootName = source.lastPathComponent
        var entries: [(path: String, relative: String)] = [(source.path, rootName)]
        var isDirectory: ObjCBool = false
        if fm.fileExists(atPath: source.path, isDirectory: &isDirectory), isDirectory.boolValue {
            let subpaths = try fm.subpathsOfDirectory(atPath: source.path).sorted()
            entries += subpaths.map { (source.appendingPathComponent($0).path, rootName + "/" + $0) }
        }

        guard fm.createFile(atPath: destination.path, contents: nil),
              let output = FileHandle(forWritingAtPath: destination.path) else {
            throw WriteError(errorDescription: "Não foi possível criar \(destination.lastPathComponent).")
        }
        defer { try? output.close() }

        // Assinatura do RAR 5.0 + cabeçalho principal (tipo 1, sem opções)
        try output.write(contentsOf: [0x52, 0x61, 0x72, 0x21, 0x1A, 0x07, 0x01, 0x00])
        try output.write(contentsOf: block(type: 1, body: vint(0)))

        for entry in entries {
            let name = (entry.relative as NSString).lastPathComponent
            if name == ".DS_Store" { continue }
            let attributes = try fm.attributesOfItem(atPath: entry.path)
            let type = attributes[.type] as? FileAttributeType
            let permissions = UInt64((attributes[.posixPermissions] as? NSNumber)?.uint16Value ?? 0o644)
            let modified = (attributes[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0
            let mtime = UInt32(clamping: Int64(max(0, modified)))
            // Nomes em UTF-8 e na forma composta (NFC), que é a que o Windows espera.
            let nameBytes = Array(entry.relative.precomposedStringWithCanonicalMapping.utf8)

            switch type {
            case .typeDirectory?:
                // Flags do arquivo: 0x01 = pasta, 0x02 = tem data de modificação
                var body = vint(0x01 | 0x02) + vint(0) + vint(0o040000 | permissions)
                body += le32(mtime) + vint(0) + vint(1) + vint(UInt64(nameBytes.count)) + nameBytes
                // Pastas não têm dados, mas o WinRAR (e o libarchive) esperam o campo de tamanho com 0.
                try output.write(contentsOf: block(type: 2, body: body, dataSize: 0))

            case .typeRegular?:
                progress(entry.relative)
                let size = (attributes[.size] as? NSNumber)?.uint64Value ?? 0
                let crc = try crc32(ofFileAt: entry.path)
                // 0x02 = tem data de modificação, 0x04 = tem CRC32 dos dados.
                // Compressão 0 = método "armazenar"; sistema 1 = Unix.
                var body = vint(0x02 | 0x04) + vint(size) + vint(0o100000 | permissions)
                body += le32(mtime) + le32(crc) + vint(0) + vint(1) + vint(UInt64(nameBytes.count)) + nameBytes
                try output.write(contentsOf: block(type: 2, body: body, dataSize: size))
                try copy(fileAt: entry.path, to: output)

            default:
                continue  // atalhos (links simbólicos) e arquivos especiais ficam de fora
            }
        }

        // Cabeçalho de fim de arquivo (tipo 5)
        try output.write(contentsOf: block(type: 5, body: vint(0)))
    }

    /// Um bloco RAR 5.0: CRC32 do cabeçalho, tamanho, tipo, flags, [tamanho dos dados], campos.
    private static func block(type: UInt64, body: [UInt8], dataSize: UInt64? = nil) -> [UInt8] {
        var header = vint(type)
        if let dataSize {
            header += vint(0x0002) + vint(dataSize)  // 0x0002 = bloco tem área de dados
        } else {
            header += vint(0)
        }
        header += body
        let sized = vint(UInt64(header.count)) + header
        return le32(CRC32.checksum(sized)) + sized
    }

    /// Inteiro de tamanho variável: 7 bits por byte, o bit mais alto indica que há mais bytes.
    private static func vint(_ value: UInt64) -> [UInt8] {
        var value = value
        var bytes: [UInt8] = []
        repeat {
            var byte = UInt8(value & 0x7F)
            value >>= 7
            if value != 0 { byte |= 0x80 }
            bytes.append(byte)
        } while value != 0
        return bytes
    }

    private static func le32(_ value: UInt32) -> [UInt8] {
        [UInt8(value & 0xFF), UInt8((value >> 8) & 0xFF), UInt8((value >> 16) & 0xFF), UInt8(value >> 24)]
    }

    private static let chunkSize = 1 << 20

    private static func crc32(ofFileAt path: String) throws -> UInt32 {
        guard let input = FileHandle(forReadingAtPath: path) else {
            throw WriteError(errorDescription: "Não foi possível ler \(path).")
        }
        defer { try? input.close() }
        var crc = CRC32()
        while let chunk = try input.read(upToCount: chunkSize), !chunk.isEmpty {
            crc.update(chunk)
        }
        return crc.value
    }

    private static func copy(fileAt path: String, to output: FileHandle) throws {
        guard let input = FileHandle(forReadingAtPath: path) else {
            throw WriteError(errorDescription: "Não foi possível ler \(path).")
        }
        defer { try? input.close() }
        while let chunk = try input.read(upToCount: chunkSize), !chunk.isEmpty {
            try output.write(contentsOf: chunk)
        }
    }
}

/// CRC32 padrão (o mesmo do ZIP), usado pelo RAR 5.0 nos cabeçalhos e nos dados.
struct CRC32 {
    private static let table: [UInt32] = (0..<256).map { n in
        var c = UInt32(n)
        for _ in 0..<8 { c = c & 1 != 0 ? 0xEDB8_8320 ^ (c >> 1) : c >> 1 }
        return c
    }

    private var crc: UInt32 = 0xFFFF_FFFF
    var value: UInt32 { crc ^ 0xFFFF_FFFF }

    mutating func update<Bytes: Sequence>(_ bytes: Bytes) where Bytes.Element == UInt8 {
        var c = crc
        Self.table.withUnsafeBufferPointer { table in
            for byte in bytes { c = table[Int((c ^ UInt32(byte)) & 0xFF)] ^ (c >> 8) }
        }
        crc = c
    }

    static func checksum(_ bytes: [UInt8]) -> UInt32 {
        var crc = CRC32()
        crc.update(bytes)
        return crc.value
    }
}
