# ssh-agent-monitor

Keep your SSH agent socket working in long-running tmux sessions.

## Problem

When using SSH agent forwarding with tmux:
1. You SSH into a machine with agent forwarding (creates `/tmp/ssh-XXXX/agent.YYYY`)
2. Start a tmux session
3. Disconnect and reconnect later (new socket created, old one gone)
4. tmux still has the old `SSH_AUTH_SOCK`, SSH operations fail

## Solution

ssh-agent-monitor maintains a stable symlink at `$XDG_RUNTIME_DIR/ssh-auth-sock` that always points to the newest working SSH agent socket. Your shell and tmux sessions reference this symlink, which stays valid across reconnects.

## Requirements

- Linux with systemd
- `inotify-tools` (for `inotifywait`)
- `openssh-client` (for `ssh-add`)

## Installation

```bash
# Clone to recommended location
git clone git@github.com:msch/ssh-agent-monitor.git ~/.local/share/ssh-agent-monitor
cd ~/.local/share/ssh-agent-monitor

# Install (sets up systemd service, ~/.ssh/rc, and shell config)
make install
```

This will:
- Check that `inotifywait` and `ssh-add` are available
- Install and start the systemd user service
- Set up `~/.ssh/rc` (creates a symlink to our script, or adds a line to run it if file exists)
- Detect your shell and add `SSH_AUTH_SOCK` export to `.bashrc` or `.zshrc` (`.zshrc.local` takes precedence if it exists)

Then restart your shell or run `source ~/.bashrc` (or `~/.zshrc`, etc.).

## How It Works

1. The monitor scans `/tmp/ssh-*` directories for agent sockets
2. Tests each socket with `ssh-add -l` to find a working one
3. Updates the symlink `$XDG_RUNTIME_DIR/ssh-auth-sock` atomically
4. Uses `inotifywait` to watch for socket changes
5. On new SSH connection, `~/.ssh/rc` triggers a rescan by touching the symlink

## Uninstall

```bash
make uninstall
```

This stops and disables the systemd service. If `~/.ssh/rc` was a symlink to our script, it will be removed. If it was an existing file with a source line added, you'll be prompted to remove that line manually. The shell config modification is left in place for manual cleanup.

## License

MIT
