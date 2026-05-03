import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class AudioChunkerService {
  static const int maxGroqFileBytes = 25 * 1024 * 1024;
  static const int _targetSampleRate = 16000;
  static const int _targetChannels = 1;
  static const int _targetBitsPerSample = 16;
  static const int _overlapSeconds = 3;

  Future<ChunkingResult> prepareForUpload(
    String audioPath, {
    int maxBytes = maxGroqFileBytes,
  }) async {
    final file = File(audioPath);
    if (!await file.exists()) {
      throw const ChunkingException('Archivo no encontrado');
    }

    final fileSize = await file.length();
    if (fileSize <= maxBytes) {
      return ChunkingResult(
        chunks: [audioPath],
        isChunked: false,
        tempFiles: [],
      );
    }

    final ext = p.extension(audioPath).toLowerCase();
    if (ext != '.wav') {
      throw const ChunkingException(
        'Solo se puede fragmentar WAV. Para otros formatos usa un archivo menor al limite.',
      );
    }

    return _chunkWav(audioPath, maxBytes);
  }

  Future<ChunkingResult> _chunkWav(String audioPath, int maxBytes) async {
    final sourceBytes = await File(audioPath).readAsBytes();
    final header = sourceBytes.buffer.asByteData();

    if (sourceBytes.length < 44 ||
        _readFourCc(sourceBytes, 0) != 'RIFF' ||
        _readFourCc(sourceBytes, 8) != 'WAVE') {
      throw const ChunkingException('Cabecera WAV invalida');
    }

    int dataOffset = 0;
    int dataLength = 0;
    var offset = 12;
    while (offset + 8 <= sourceBytes.length) {
      final chunkId = _readFourCc(sourceBytes, offset);
      final chunkSize = header.getUint32(offset + 4, Endian.little);
      if (chunkId == 'data') {
        dataOffset = offset + 8;
        dataLength = chunkSize;
        break;
      }
      offset += 8 + chunkSize + (chunkSize.isOdd ? 1 : 0);
    }

    if (dataOffset == 0 || dataLength == 0) {
      throw const ChunkingException('No se encontro chunk de datos WAV');
    }

    final bytesPerSecond = _targetSampleRate * _targetChannels * (_targetBitsPerSample ~/ 8);
    final maxDataBytes = maxBytes - 44;
    final chunkDataBytes = maxDataBytes - (maxDataBytes % bytesPerSecond);
    final overlapBytes = _overlapSeconds * bytesPerSecond;

    final chunks = <String>[];
    final tempFiles = <String>[];
    final tempDir = await getTemporaryDirectory();
    final baseName = p.basenameWithoutExtension(audioPath);

    var readOffset = 0;
    var chunkIndex = 0;

    while (readOffset < dataLength) {
      final endOffset = (readOffset + chunkDataBytes).clamp(0, dataLength);
      final chunkBytes = Uint8List.sublistView(
        sourceBytes,
        dataOffset + readOffset,
        dataOffset + endOffset,
      );

      final wavChunk = _buildWavChunk(chunkBytes);
      final chunkPath = p.join(tempDir.path, '${baseName}_chunk_$chunkIndex.wav');
      await File(chunkPath).writeAsBytes(wavChunk, flush: true);

      chunks.add(chunkPath);
      tempFiles.add(chunkPath);

      if (endOffset >= dataLength) break;

      readOffset = endOffset - overlapBytes;
      if (readOffset <= 0) readOffset = endOffset;
      chunkIndex++;
    }

    return ChunkingResult(
      chunks: chunks,
      isChunked: true,
      tempFiles: tempFiles,
      totalChunks: chunks.length,
    );
  }

  Uint8List _buildWavChunk(Uint8List pcmData) {
    final totalSize = 44 + pcmData.length;
    final output = Uint8List(totalSize);
    final header = output.buffer.asByteData();

    _writeFourCc(output, 0, 'RIFF');
    header.setUint32(4, totalSize - 8, Endian.little);
    _writeFourCc(output, 8, 'WAVE');
    _writeFourCc(output, 12, 'fmt ');
    header.setUint32(16, 16, Endian.little);
    header.setUint16(20, 1, Endian.little);
    header.setUint16(22, _targetChannels, Endian.little);
    header.setUint32(24, _targetSampleRate, Endian.little);
    header.setUint32(
      28,
      _targetSampleRate * _targetChannels * (_targetBitsPerSample ~/ 8),
      Endian.little,
    );
    header.setUint16(
      32,
      _targetChannels * (_targetBitsPerSample ~/ 8),
      Endian.little,
    );
    header.setUint16(34, _targetBitsPerSample, Endian.little);
    _writeFourCc(output, 36, 'data');
    header.setUint32(40, pcmData.length, Endian.little);
    output.setRange(44, totalSize, pcmData);
    return output;
  }

  Future<void> cleanup(List<String> tempFiles) async {
    for (final path in tempFiles) {
      try {
        final file = File(path);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (_) {}
    }
  }

  String _readFourCc(Uint8List bytes, int offset) {
    return String.fromCharCodes(bytes.sublist(offset, offset + 4));
  }

  void _writeFourCc(Uint8List bytes, int offset, String value) {
    bytes.setRange(offset, offset + 4, value.codeUnits);
  }
}

class ChunkingResult {
  const ChunkingResult({
    required this.chunks,
    required this.isChunked,
    required this.tempFiles,
    this.totalChunks,
  });

  final List<String> chunks;
  final bool isChunked;
  final List<String> tempFiles;
  final int? totalChunks;
}

class ChunkingException implements Exception {
  const ChunkingException(this.message);

  final String message;

  @override
  String toString() => message;
}
