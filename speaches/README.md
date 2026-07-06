# Speaches

Local OpenAI-compatible speech-to-text and text-to-speech API server.

This setup uses the CPU image and keeps Speaches behind the shared Caddy proxy.

## Start

```bash
docker compose up -d
```

The first transcription request downloads the selected model into the
`hf-hub-cache` Docker volume.

## URL

```text
https://speaches.${BASE_DOMAIN}
```

## Example transcription request

```bash
curl https://speaches.${BASE_DOMAIN}/v1/audio/transcriptions \
  -F file=@audio.mp3 \
  -F model=Systran/faster-whisper-small
```

For faster transcription on a host with NVIDIA GPU support, switch the image to
`ghcr.io/speaches-ai/speaches:latest-cuda` and add the GPU device settings from
the Speaches installation docs.
