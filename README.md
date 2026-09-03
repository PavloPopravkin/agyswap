# agyswap

Multi-account rotation for the **Antigravity CLI** (`agy`, Google AI Pro).

One Google account gives you a 5-hour window and a weekly window of Antigravity
quota. Run an agent loop against it and the account is dark for hours or days,
with every call failing and nothing switching over. `agyswap` sits in front of
the real `agy` binary and makes several accounts behave like one big quota:

- **Round-robin per call.** Each account is a HOME directory holding its own
  `agy` auth, so switching is instant and needs no re-login.
- **Walls instead of failures.** An account that reports quota exhaustion leaves
  the rotation until its real reset time and comes back on its own.
- **Two baskets, tracked apart.** Antigravity meters *Gemini models* and
  *Claude and GPT models* separately per account, so a spent Gemini quota no
  longer hides a full Claude quota on the same account.
- **A quota prober, not guesswork.** `agyswap probe` reads `/quota` per account
  (a metadata turn, no model tokens) and walls from the panel's own reset times.
- **Optional pacing.** Spend at most N points of the weekly quota per day, so a
  fresh week is not burned in an afternoon.
- **Headless by design.** No GUI, no daemon, no config file: a wrapper script
  and a cron entry. Install it as `agy` earlier in `PATH` and every existing
  script, agent and IDE integration rotates without a single edit.

Tested on Linux; it is POSIX-ish bash plus Python 3 and should work on macOS.

## Install

```bash
git clone https://github.com/PavloPopravkin/agyswap.git
cd agyswap && ./install.sh          # copies to ~/.local/bin
```

`./install.sh --as-agy` additionally drops an `agy` symlink into `~/.local/bin`
so anything calling `agy` goes through the rotation. Keep the real binary
somewhere else in `PATH` (or point `AGYSWAP_AGY` at it) — agyswap never calls
itself.

## Quickstart

```bash
agyswap login 1      # sign in with the first Google account, then exit
agyswap login 2      # second account, and so on
agyswap list         # accounts and their wall state
agyswap probe        # read /quota per account, wall the spent ones

agyswap -p "hello"   # runs on the next live account
agy -p "hello"       # same thing when installed with --as-agy
```

Everything after the subcommand is passed to `agy` untouched, so
`agyswap --model claude-opus-4-6 -p "review this diff"` works exactly like the
real CLI, only on an account that still has quota.

Keep the walls honest with cron:

```cron
*/10 * * * * ~/.local/bin/agyswap probe >> ~/.agyswap/state/probe.log 2>&1
```

## Commands

| Command | What it does |
|---|---|
| `agyswap <agy args...>` | run `agy` on the next live account |
| `agyswap login <n>` | authenticate account slot `<n>` |
| `agyswap list` | accounts, wall state, time to reset |
| `agyswap probe` | read `/quota` per account and wall/unwall from it |
| `agyswap unwall <n\|all>` | clear walls by hand |
| `agyswap which` | show the real `agy` binary and the state directory |

## Environment

| Variable | Default | Meaning |
|---|---|---|
| `AGYSWAP_DIR` | `~/.agyswap` | accounts (`slots/slotN/`) and state |
| `AGYSWAP_AGY` | first `agy` in `PATH` that is not agyswap | real CLI binary |
| `AGYSWAP_SLOT` | — | pin one account for this call |
| `AGYSWAP_NOTIFY_CMD` | — | shell command called with a message when an account is walled |
| `AGYSWAP_DAILY_BUDGET_PCT` | `14` | weekly-quota points one account may spend per UTC day (`0` disables pacing) |
| `AGYSWAP_WALL_PCT` | `3` | remaining % at or below which the prober walls a basket |

## How it works

Accounts are directories, not config entries:

```
~/.agyswap/
  slots/slot1/.gemini/antigravity-cli/jetski_state.pbtxt   # account 1 auth
  slots/slot2/.gemini/antigravity-cli/jetski_state.pbtxt   # account 2 auth
  state/wall-2        # slot2 Gemini basket, line 1 = reset epoch
  state/wall-cg-2     # slot2 Claude/GPT basket
  state/wall-pace-1   # slot1 spent its daily share
  state/quota.json    # last probe snapshot
  state/agyswap.log   # which account served which call
```

A call picks the next account by a shared counter, skips the walled ones, and
runs the real CLI with `HOME` pointed at that slot. Adding an account is
`agyswap login <n>` and nothing else; removing one is `rm -rf slots/slotN`.

Three details that are easy to get wrong, and are handled here:

1. **Only agy's own error field may wall an account.** Matching "rate limit" or
   "quota" anywhere in the output walls a healthy account the moment a model
   *discusses* a rate limit — a code review did exactly that here. The wrapper
   inspects the `"error"` field only, and treats the reactive wall as a backstop
   behind the prober.
2. **Two quota baskets, two walls.** Reading only "Gemini Models" from the quota
   panel hides a full "Claude and GPT models" basket on a slot whose Gemini
   quota is spent.
3. **A soft pace wall must be bypassable.** When every account is paced out the
   call still goes through: pacing smooths spend, it does not cap it. A hard
   quota wall is never bypassed.

## Tests

```bash
test/smoke.sh
```

Runs rotation, walls, basket separation, the false-wall case, the prober and the
pacing budget against a stub CLI — no account, no quota, no network.

## Related projects

`agyswap` is deliberately a headless CLI wrapper. If you want a GUI, a TUI or an
API proxy instead:

- [lbjlaq/Antigravity-Manager](https://github.com/lbjlaq/Antigravity-Manager) — desktop account manager and switcher for the Antigravity IDE
- [jlcodes99/cockpit-tools](https://github.com/jlcodes99/cockpit-tools) — account manager across Antigravity, Codex, Copilot, Cursor, Gemini
- [aklkbqx/agy-swap](https://github.com/aklkbqx/agy-swap) — TUI switcher and quota tracker for the Antigravity CLI
- [zcop/agy-cli-manager](https://github.com/zcop/agy-cli-manager) — multi-account manager with quota-aware failover
- [polystree/openag](https://github.com/polystree/openag) — multi-account pool and quota rotation
- [skainguyen1412/antigravity-usage](https://github.com/skainguyen1412/antigravity-usage) — quota and usage tracking
- [burakdede/aisw](https://github.com/burakdede/aisw) — switcher across Claude Code, Codex, Antigravity and Gemini CLI
- [realiti4/claude-swap](https://github.com/realiti4/claude-swap) — the same idea for Claude Code (`cswap`)

## License

MIT
