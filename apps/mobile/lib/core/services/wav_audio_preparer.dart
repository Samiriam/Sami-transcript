import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class WavAudioPreparer {
  static const int targetSampleRate = 16000;
  static const int targetChannels = 1;
  static const int targetBitsPerSample = 16;

  Future<PreparedAudioFile> prepareForWhisper(String audioPath) async {
    final sourceFile = File(audioPath);
    if (!await sourceFile.exists()) {
      throw const WavAudioPreparationException(
          'No se encontro el archivo de audio');
    }

    if (p.extension(audioPath).toLowerCase() != '.wav') {
      throw const WavAudioPreparationException(
        'Whisper local requiere WAV. Para audios antiguos o importados en otro formato usa OpenAI/AssemblyAI.',
      );
    }

    final sourceBytes = await sourceFile.readAsBytes();
    final info = parseHeader(sourceBytes);

    if (info.audioFormat != 1) {
      throw const WavAudioPreparationException(
        'El WAV local debe estar en PCM sin compresion.',
      );
    }

    if (info.bitsPerSample != targetBitsPerSample) {
      throw const WavAudioPreparationException(
        'El WAV local debe usar 16 bits por muestra.',
      );
    }

    if (info.sampleRate == targetSampleRate &&
        info.numChannels == targetChannels) {
      return PreparedAudioFile(path: audioPath, isTemporary: false);
    }

    final normalizedBytes =
        await Isolate.run(() => normalizeTo16KMonoPcm16(sourceBytes));
    final tempDir = await getTemporaryDirectory();
    final outputPath = p.join(
      tempDir.path,
      '${p.basenameWithoutExtension(audioPath)}_whisper_16khz.wav',
    );
    final outputFile = File(outputPath);
    await outputFile.writeAsBytes(normalizedBytes, flush: true);

    return PreparedAudioFile(path: outputFile.path, isTemporary: true);
  }

  static WavFileInfo parseHeader(Uint8List bytes) {
    if (bytes.length < 44) {
      throw const WavAudioPreparationException('Archivo WAV demasiado corto');
    }

    final header = bytes.buffer.asByteData();
    if (_readFourCc(bytes, 0) != 'RIFF' || _readFourCc(bytes, 8) != 'WAVE') {
      throw const WavAudioPreparationException(
          'El archivo no tiene cabecera WAV valida');
    }

    int? audioFormat;
    int? numChannels;
    int? sampleRate;
    int? bitsPerSample;
    int? dataOffset;
    int? dataLength;

    var offset = 12;
    while (offset + 8 <= bytes.length) {
      final chunkId = _readFourCc(bytes, offset);
      final chunkSize = header.getUint32(offset + 4, Endian.little);
      final chunkDataOffset = offset + 8;

      if (chunkDataOffset + chunkSize > bytes.length) {
        throw const WavAudioPreparationException('Cabecera WAV corrupta');
      }

      if (chunkId == 'fmt ') {
        audioFormat = header.getUint16(chunkDataOffset, Endian.little);
        numChannels = header.getUint16(chunkDataOffset + 2, Endian.little);
        sampleRate = header.getUint32(chunkDataOffset + 4, Endian.little);
        bitsPerSample = header.getUint16(chunkDataOffset + 14, Endian.little);
      } else if (chunkId == 'data') {
        dataOffset = chunkDataOffset;
        dataLength = chunkSize;
      }

      offset = chunkDataOffset + chunkSize + (chunkSize.isOdd ? 1 : 0);
    }

    if (audioFormat == null ||
        numChannels == null ||
        sampleRate == null ||
        bitsPerSample == null ||
        dataOffset == null ||
        dataLength == null) {
      throw const WavAudioPreparationException(
          'No se encontraron chunks WAV requeridos');
    }

    return WavFileInfo(
      audioFormat: audioFormat,
      numChannels: numChannels,
      sampleRate: sampleRate,
      bitsPerSample: bitsPerSample,
      dataOffset: dataOffset,
      dataLength: dataLength,
    );
  }

  static Uint8List normalizeTo16KMonoPcm16(Uint8List sourceBytes) {
    final info = parseHeader(sourceBytes);
    if (info.audioFormat != 1) {
      throw const WavAudioPreparationException(
          'Solo se puede normalizar WAV PCM sin compresion');
    }
    if (info.bitsPerSample != targetBitsPerSample) {
      throw const WavAudioPreparationException(
          'Solo se puede normalizar WAV PCM de 16 bits');
    }

    final blockAlign = info.numChannels * (info.bitsPerSample ~/ 8);
    final inputFrames = info.dataLength ~/ blockAlign;
    if (inputFrames <= 0) {
      throw const WavAudioPreparationException(
          'El WAV no contiene audio utilizable');
    }

    final pcm = sourceBytes.buffer.asByteData(info.dataOffset, info.dataLength);
    final monoSamples = List<double>.filled(inputFrames, 0);

    for (var frame = 0; frame < inputFrames; frame++) {
      var sum = 0.0;
      for (var channel = 0; channel < info.numChannels; channel++) {
        final sampleOffset = frame * blockAlign + (channel * 2);
        sum += pcm.getInt16(sampleOffset, Endian.little).toDouble();
      }
      monoSamples[frame] = sum / info.numChannels;
    }

    final targetFrames = math.max(
      1,
      (monoSamples.length * targetSampleRate / info.sampleRate).round(),
    );
    final normalizedPcm = ByteData(targetFrames * 2);

    for (var i = 0; i < targetFrames; i++) {
      final sourcePosition = i * info.sampleRate / targetSampleRate;
      final leftIndex = sourcePosition.floor().clamp(0, monoSamples.length - 1);
      final rightIndex = math.min(leftIndex + 1, monoSamples.length - 1);
      final t = sourcePosition - leftIndex;
      final interpolated = monoSamples[leftIndex] +
          (monoSamples[rightIndex] - monoSamples[leftIndex]) * t;
      final clamped = interpolated.round().clamp(-32768, 32767);
      normalizedPcm.setInt16(i * 2, clamped, Endian.little);
    }

    return _buildWavFile(normalizedPcm.buffer.asUint8List());
  }

  static Uint8List _buildWavFile(Uint8List pcmBytes) {
    final totalSize = 44 + pcmBytes.length;
    final output = Uint8List(totalSize);
    final header = output.buffer.asByteData();

    _writeFourCc(output, 0, 'RIFF');
    header.setUint32(4, totalSize - 8, Endian.little);
    _writeFourCc(output, 8, 'WAVE');
    _writeFourCc(output, 12, 'fmt ');
    header.setUint32(16, 16, Endian.little);
    header.setUint16(20, 1, Endian.little);
    header.setUint16(22, targetChannels, Endian.little);
    header.setUint32(24, targetSampleRate, Endian.little);
    header.setUint32(
        28,
        targetSampleRate * targetChannels * (targetBitsPerSample ~/ 8),
        Endian.little);
    header.setUint16(
        32, targetChannels * (targetBitsPerSample ~/ 8), Endian.little);
    header.setUint16(34, targetBitsPerSample, Endian.little);
    _writeFourCc(output, 36, 'data');
    header.setUint32(40, pcmBytes.length, Endian.little);
    output.setRange(44, totalSize, pcmBytes);
    return output;
  }

  static String _readFourCc(Uint8List bytes, int offset) {
    return String.fromCharCodes(bytes.sublist(offset, offset + 4));
  }

  static void _writeFourCc(Uint8List bytes, int offset, String value) {
    bytes.setRange(offset, offset + 4, value.codeUnits);
  }
}

class PreparedAudioFile {
  const PreparedAudioFile({required this.path, required this.isTemporary});

  final String path;
  final bool isTemporary;
}

class WavFileInfo {
  const WavFileInfo({
    required this.audioFormat,
    required this.numChannels,
    required this.sampleRate,
    required this.bitsPerSample,
    required this.dataOffset,
    required this.dataLength,
  });

  final int audioFormat;
  final int numChannels;
  final int sampleRate;
  final int bitsPerSample;
  final int dataOffset;
  final int dataLength;
}

class WavAudioPreparationException implements Exception {
  const WavAudioPreparationException(this.message);

  final String message;

  @override
  String toString() => message;
}
