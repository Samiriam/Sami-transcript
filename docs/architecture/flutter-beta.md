# Flutter Beta Architecture

## Scope

This document describes the personal beta architecture for Sami Transcribe.

## Layers

- Presentation: Flutter widgets and screens.
- Domain: recording and transcription entities.
- Data: local repositories and persistence.

## Current storage

- SQLite or Drift for metadata.
- Local filesystem for audio and exports.

## Future migration

The repository contracts are kept stable so that a remote backend can be added later without rewriting UI flows.
