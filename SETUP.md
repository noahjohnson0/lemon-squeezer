# Setup

## Pointing at your Ollama host

The eval harness defaults to `http://localhost:11434`. To point at a remote Ollama box:

```bash
export OLLAMA_API_BASE=http://YOUR_OLLAMA_HOST:11434
```

For the per-run hardware telemetry sampler (optional — capture GPU temp / VRAM / power / fan during each eval), point at an SSH-reachable host that has `nvidia-smi`:

```bash
export SAMPLER_SSH_TARGET=user@YOUR_GPU_HOST
```

If `SAMPLER_SSH_TARGET` is unset, the sampler skips remote GPU telemetry and only logs host load average.

## Persisting your local config

`bin/eval-run` auto-sources `~/.config/lemon-squeezer.env` if it exists. Drop your env vars there and they'll apply to every run without polluting the repo.

```bash
mkdir -p ~/.config
cat > ~/.config/lemon-squeezer.env <<'ENV'
export OLLAMA_API_BASE=http://192.168.x.x:11434
export SAMPLER_SSH_TARGET=user@192.168.x.x
ENV
chmod 600 ~/.config/lemon-squeezer.env
```

## Dependencies

- `python3` (stdlib only for `bin/squeezer.py`; `numpy` + `sympy` for some eval rubrics)
- `gtimeout` (macOS: `brew install coreutils`)
- `ollama` running locally or on the `OLLAMA_API_BASE` host
- One of: [aider](https://aider.chat) (`pipx install aider-chat`), [pi](https://pi.dev) (`bun add -g @earendil-works/pi-coding-agent`)

## Run an eval

```bash
bin/eval-run aider bug-fix qwen3-coder:30b-a3b-q4_K_M baseline
```
