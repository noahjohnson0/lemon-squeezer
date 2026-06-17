# Cloud-harness adapters

Each `<name>.sh` here lets an **external coding-agent CLI** be benchmarked in the
cloud, the same way `bin/harnesses/<name>.sh` lets one run locally. This is what
makes the leaderboard able to evaluate *any* harness (aider, pi, opencode, crush,
cline, claude-code, codex, ...) against OpenRouter models - not just the built-in
`squeezer`/`aider`/pipeline paths hardcoded in `cloud-run`.

## Contract

`bin/cloud-run <eval> <model-slug> <tag> --harness-adapter <name>` invokes:

```
bash bin/cloud-harnesses/<name>.sh <ws> <prompt_file> <model_slug> <run_dir> <base_url>
```

with `$LEMON_API_KEY` (the OpenRouter bearer) in the environment. The adapter must:

1. Drive its CLI against the OpenAI-compatible endpoint `<base_url>` using
   `<model_slug>`, editing files in `<ws>` to solve `<prompt_file>`.
2. Write four counter files into `<run_dir>` (plain numbers):
   - `tokens_in`, `tokens_out` - prompt/completion tokens (0 if unknown)
   - `tool_calls` - file-edit / tool invocations (0 if unknown)
   - `cost` - USD spent on the run (0 if the CLI doesn't report it)

Anything the adapter prints to stdout is captured into `<run_dir>/stdout.log` by
`cloud-run`. `cloud-run` then runs the eval's real `rubric.sh` and writes
`meta.json` (reading those four counter files), so the adapter only worries about
*running the agent* and *reporting counters*.

## Available adapters

| adapter | CLI | provider | notes |
|---|---|---|---|
| `aider` | aider | OpenRouter | parses tokens + cost from its log |
| `opencode` | opencode (SST) | OpenRouter | JSON event stream; tokens + cost |
| `crush` | crush (Charm) | OpenRouter | no stdout usage (cost reads 0) |
| `pi` | pi (@earendil-works) | OpenRouter | native openrouter provider; don't pass `--thinking off` |
| `cline` | clite (@cline/cli) | OpenRouter | weak models flail on its XML format; heavy context = high cost |
| `codex` | codex (OpenAI) | **native OpenAI** | uses its own auth; pass `--host openai`; slug ignored (set `CODEX_MODEL`) |
| `claude-code` | claude (Anthropic) | **native Anthropic** | uses its own auth; pass `--host anthropic`; slug = model alias (sonnet/opus) |

All validated on `cli-tool` (each scored 100 with a capable model). Sweep one with:

```
# OpenRouter harness across the suite:
bin/cloud-matrix --arms <arms.json> ...   # arm: {"label":"pi","model":"openai/gpt-oss-20b","adapter":"pi"}
# or a single cell:
bin/cloud-run <eval> <model-slug> <tag> --harness-adapter pi
bin/cloud-run <eval> sonnet <tag> --harness-adapter claude-code --host anthropic
```

## Notes

- Set `BROWSER` to a no-op if the CLI ever opens URLs (cloud-run already does this
  in the adapter env, but harmless to repeat).
- The workspace is pre-populated with the eval's starter files (`files/` + `setup.sh`)
  before the adapter runs.
- Use `cloud-matrix` arms with `"harness_adapter": "<name>"` to sweep a harness
  across the suite.
