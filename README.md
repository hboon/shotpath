# shotpath

![shotpath](assets/banner.png)

Watch your macOS Desktop for screenshots and automatically copy the absolute file path to your clipboard. Useful for quickly pasting screenshot paths into coding agents, chat apps, or terminals as you take them.

## Install

```
brew tap hboon/tap
brew install shotpath
```

## Usage

Run manually:

```
shotpath
```

Or auto-start at login:

```
brew services start hboon/tap/shotpath
```

To stop the background service:

```
brew services stop hboon/tap/shotpath
```

## Build and Install from Source

**Requirements:** Xcode Command Line Tools (`xcode-select --install`)

```sh
git clone https://github.com/lingster/shotpath.git
cd shotpath
make
sudo make install
```

The binary is installed to `/usr/local/bin/shotpath`. To use a different prefix:

```sh
sudo make install PREFIX=/opt/homebrew
```

**Auto-start at login** (installs a LaunchAgent):

```sh
make install-launchagent
```

**Uninstall:**

```sh
make uninstall
```

## Mode Toggle

By default, shotpath copies the **file path** to your clipboard. You can toggle to **image mode** which copies the actual screenshot image instead.

Press `Cmd+Shift+E` to toggle between modes. A notification confirms the switch.

**Note:** The hotkey requires Accessibility access. Grant it in **System Settings > Privacy & Security > Accessibility** for the terminal or process running shotpath.

## Configuration

Settings are stored in `~/.config/shotpath/config.yaml` (created automatically on first run):

```yaml
# Mode: "path" copies the file path, "image" copies the image data
mode: path

# Global hotkey to toggle between path and image mode
# Format: modifier+modifier+key
# Supported modifiers: cmd, shift, ctrl, option
hotkey: cmd+shift+e
```

Edit this file to change the default mode or remap the hotkey to a different combo.

## How it works

Monitors your screenshot save folder for new files matching the macOS screenshot naming pattern (`Screenshot ... at ... .png`). The folder is read from the `com.apple.screencapture` preference (set via System Settings → Screenshots) and falls back to `~/Desktop` if unset. When a screenshot appears, either its absolute path or the image data is copied to your clipboard (depending on the current mode) and a notification is shown.

## Blog Post

[shotpath: Automatically Copy macOS Screenshot Paths](https://hboon.com/shotpath-automatically-copy-macos-screenshot-paths/)

## License

MIT
