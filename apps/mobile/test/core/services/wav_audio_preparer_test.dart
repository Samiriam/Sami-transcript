import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sami_transcribe/core/services/wav_audio_preparer.dart';

void main() {
  group('WavAudioPreparer', () {
    test('parseHeader reads PCM wav metadata', () {
      final wavBytes = _buildTestWav(
        sampleRate: 44100,
        numChannels: 2,
        frames: 8,
      );

      final info = WavAudioPreparer.parseHeader(wavBytes);

      expect(info.audioFormat, 1);
      expect(info.sampleRate, 44100);
      expect(info.numChannels, 2);
      expect(info.bitsPerSample, 16);
      expect(info.dataLength, greaterThan(0));
    });

    test('normalizeTo16KMonoPcm16 converts wav to 16k mono pcm', () {
      final wavBytes = _buildTestWav(
        sampleRate: 44100,
        numChannels: 2,
        frames: 4410,
      );

      final normalized = WavAudioPreparer.normalizeTo16KMonoPcm16(wavBytes);
      final info = WavAudioPreparer.parseHeader(normalized);

      expect(info.audioFormat, 1);
      expect(info.sampleRate, WavAudioPreparer.targetSampleRate);
      expect(info.numChannels, WavAudioPreparer.targetChannels);
      expect(info.bitsPerSample, WavAudioPreparer.targetBitsPerSample);
      expect(info.dataLength, greaterThan(0));
    });
  });
}

Uint8List _buildTestWav({
  required int sampleRate,
  required int numChannels,
  required int frames,
}) {
  final pcmBytes = ByteData(frames * numChannels * 2);
  for (var frame = 0; frame < frames; frame++) {
    for (var channel = 0; channel < numChannels; channel++) {
      final value = ((frame * 37) % 32767) - 16384;
      pcmBytes.setInt16(
          (frame * numChannels + channel) * 2, value, Endian.little);
    }
  }

  final dataLength = pcmBytes.lengthInBytes;
  final totalSize = 44 + dataLength;
  final bytes = Uint8List(totalSize);
  final header = bytes.buffer.asByteData();
  bytes.setRange(0, 4, 'RIFF'.codeUnits);
  header.setUint32(4, totalSize - 8, Endian.little);
  bytes.setRange(8, 12, 'WAVE'.codeUnits);
  bytes.setRange(12, 16, 'fmt '.codeUnits);
  header.setUint32(16, 16, Endian.little);
  header.setUint16(20, 1, Endian.little);
  header.setUint16(22, numChannels, Endian.little);
  header.setUint32(24, sampleRate, Endian.little);
  header.setUint32(28, sampleRate * numChannels * 2, Endian.little);
  header.setUint16(32, numChannels * 2, Endian.little);
  header.setUint16(34, 16, Endian.little);
  bytes.setRange(36, 40, 'data'.codeUnits);
  header.setUint32(40, dataLength, Endian.little);
  bytes.setRange(44, totalSize, pcmBytes.buffer.asUint8List());
  return bytes;
}
