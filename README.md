# gta-modfind

A bash script that automatically finds which mods are crashing GTA V on Linux (Steam + Proton).

Instead of disabling mods one at a time by hand, it splits your mods into groups, launches the game, checks whether it crashed, and keeps narrowing down until it has found every broken mod. It can also detect **conflicts**: mods that work fine alone but crash when used together.

## Why I made this

I got GTA V mods running on Linux, which took a full day of troubleshooting. When something broke, finding the bad mod meant moving files in and out and relaunching the game over and over. I wanted a tool that does that loop for me.

## How it works

1. **Baseline test**: launches the game with all mods disabled. If it still crashes, the problem is Proton, the Rockstar Launcher, or Script Hook V itself, not a mod.
2. **Binary search**: tests all mods together. If that fails, it splits them in half and tests each half, repeating until each bad mod is isolated.
3. **Conflict detection**: if a group fails but both of its halves pass, those mods conflict with each other.
4. **Automatic restore**: disabled mods are moved to a temporary `_modfind_parked` folder and always put back when the script ends, even if you stop it with Ctrl+C.

With 40 mods and 1 broken one, it takes about 6 test launches instead of 40.

## Requirements

- Linux with Steam and GTA V running through Proton
- Script Hook V and an ASI loader already installed
- Bash 4.4 or newer

## Usage

```bash
chmod +x gta-modfind.sh
./gta-modfind.sh
```

If your game isn't in the default Steam folder:

```bash
GAME_DIR="/path/to/Grand Theft Auto V" ./gta-modfind.sh
```

For GTA V Enhanced, add `APPID=3240220`.

### Modes

| Mode | Command | Description |
|---|---|---|
| ask (default) | `./gta-modfind.sh` | The script launches the game and you answer y/n after each test. Most accurate; catches freezes and Story Mode crashes. |
| auto | `MODE=auto ./gta-modfind.sh` | Fully hands-off. A test passes if the game stays running for `STABLE_TIME` seconds. |
| dryrun | `MODE=dryrun FAKE_BAD="a.asi b.asi" ./gta-modfind.sh` | Practice run with fake mods. Doesn't touch the game. |

### Settings

| Variable | Default | Description |
|---|---|---|
| `GAME_DIR` | `~/.steam/steam/steamapps/common/Grand Theft Auto V` | Game install folder |
| `APPID` | `271590` | Steam app ID (`271590` Legacy, `3240220` Enhanced) |
| `MODE` | `ask` | `ask`, `auto`, or `dryrun` |
| `BOOT_TIMEOUT` | `180` | Auto mode: seconds to wait for the game to start |
| `STABLE_TIME` | `90` | Auto mode: seconds the game must stay running to pass |

**Tip for auto mode:** turn off the landing page in GTA's settings so the game loads straight into Story Mode, then set `STABLE_TIME` to longer than a normal load takes (for example `STABLE_TIME=240`).

## Example output

Dryrun with 7 mods, one of them broken:

```
Mode: dryrun | Mods to test (7): broken.asi carspawner.asi hud.asi police.asi traffic.asi trainer.asi weather.asi

Test #1 with 0 mod(s): (none)
  -> PASS

Test #2 with 7 mod(s): broken.asi carspawner.asi hud.asi police.asi traffic.asi trainer.asi weather.asi
  -> FAIL

Test #3 with 3 mod(s): broken.asi carspawner.asi hud.asi
  -> FAIL

Test #4 with 1 mod(s): broken.asi
  -> FAIL
  *** Found bad mod: broken.asi

Test #5 with 2 mod(s): carspawner.asi hud.asi
  -> PASS

Test #6 with 4 mod(s): police.asi traffic.asi trainer.asi weather.asi
  -> PASS

================ RESULTS (6 test runs) ================
Bad mods:
  - broken.asi
```

Results are also saved to `_modfind_results.txt` in the game folder.

