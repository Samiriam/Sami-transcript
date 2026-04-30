# Flutter Beta Architecture

## Scope

This document describes the personal beta architecture for Sami Transcribe.

## Layers

- Presentation: Flutter widgets, screens and providers.
- Domain: recording and transcription entities.
- Data: local repositories and persistence.

## Current storage

- SQLite via sqflite for metadata.
- Local filesystem for audio and exports.
- SharedPreferences for lightweight settings and engine selection.

## Future migration

The repository contracts are kept stable so that a remote backend can be added later without rewriting UI flows.

## Current transcription strategy

- Whisper local is the default engine.
- OpenAI-compatible and AssemblyAI engines are configurable from settings.
- Summaries follow the same engine routing when available.
