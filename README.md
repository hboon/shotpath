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

## How it works

Monitors `~/Desktop` for new files matching the macOS screenshot naming pattern (`Screenshot ... at ... .png`). When a screenshot appears, its absolute path is copied to your clipboard and a notification is shown.

## Blog Post

[shotpath: Automatically Copy macOS Screenshot Paths](https://hboon.com/shotpath-automatically-copy-macos-screenshot-paths/)

## License

MIT
