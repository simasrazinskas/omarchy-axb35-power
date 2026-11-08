# omarchy-axb35-power

[![check](https://github.com/simasrazinskas/omarchy-axb35-power/actions/workflows/check.yml/badge.svg)](https://github.com/simasrazinskas/omarchy-axb35-power/actions/workflows/check.yml)

Quiet, balanced or performance mode for the GMKtec EVO-X2 (Sixunited AXB35 board, Ryzen AI Max+ 395) on [Omarchy](https://omarchy.org/), switched from the bar.

Each mode sets the embedded controller's APU power mode and all three fan curves together:

| Mode | APU power mode | CPU fans full speed at | System fan full speed at | Measured, 32 busy threads |
|---|---|---|---|---|
| Quiet | `quiet` | 90 °C | 88 °C | ~2.8 GHz, ~52 °C |
| Balanced | `balanced` | 88 °C | 85 °C | not measured |
| Performance | `performance` | 85 °C | 80 °C | ~4.2 GHz, ~93 °C |

The chosen mode survives a reboot. The front P-mode button still changes the APU power mode on its own; the bar always shows what the embedded controller reports.

## Requirements

- A GMKtec EVO-X2 or another AXB35-based mini PC.
- Omarchy with the Omarchy shell (bar plugins).
- The [ec-su_axb35-linux](https://github.com/cmetz/ec-su_axb35-linux) driver, loaded at boot: `/sys/class/ec_su_axb35` must exist.

This tool writes fan curves and the power mode to the embedded controller through that driver. A curve that ramps too late lets the chip run hotter; the chip still protects itself by throttling. Use it at your own risk (see the license).

## Install

```sh
git clone https://github.com/simasrazinskas/omarchy-axb35-power.git ~/src/omarchy-axb35-power
~/src/omarchy-axb35-power/install.sh
```

It installs:

- `/usr/local/bin/axb35-power`, root-owned, the only thing that writes to the embedded controller;
- `axb35-power.service`, which restores the saved mode at boot;
- `/etc/sudoers.d/axb35-power`, so members of `wheel` can switch modes without a password (only the three mode commands);
- the bar widget, linked into `~/.config/omarchy/plugins/axb35.power`, so `git pull` updates it.

## Use

- **Bar:** click the speedometer for the panel (mode buttons, temperature, fan speeds; arrow keys and Enter work too). Right-click cycles to the next mode.
- **Terminal:** `sudo axb35-power quiet|balanced|performance`, or `axb35-power status`.
- **Keybinding:** `omarchy-shell axb35.power toggle` opens the panel.

## Tune

A fan curve is five temperatures (°C) at which the fan steps up to 20, 40, 60, 80 and 100 %, and five at which it steps back down. Edit `curves()` in `bin/axb35-power`, update the table in `test/axb35-power.test.sh`, run `./check.sh`, then rerun `install.sh`.

## Uninstall

```sh
omarchy plugin disable axb35.power
rm ~/.config/omarchy/plugins/axb35.power
sudo systemctl disable axb35-power.service
sudo rm /etc/systemd/system/axb35-power.service /etc/sudoers.d/axb35-power /usr/local/bin/axb35-power
sudo rm -r /var/lib/axb35-power
```

## Check

```sh
./check.sh
```

It runs the same checks as CI: `shellcheck` and `shfmt` (v3.14.1, `-i 2 -ci`) on the scripts, `jq` on the JSON, the plugin id against its folder, `visudo` on the sudoers rule, `systemd-analyze verify` on the unit, and `test/axb35-power.test.sh`, which drives the helper against a fake sysfs tree and checks every mode's writes, the boot restore and the refusals. On an Omarchy machine it also runs `omarchy plugin validate`. CI also scans the whole history for secrets with `gitleaks git .`.

## License

[MIT](LICENSE). The ec-su_axb35-linux driver is a separate project under its own license (GPL-2.0).
