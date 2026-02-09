SHELL := /bin/bash

BINDIR := $(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))
SSHRC := $(HOME)/.ssh/rc
SYSTEMD_DIR := $(HOME)/.config/systemd/user
SERVICE_NAME := ssh-agent-monitor.service
SERVICE_SRC := ssh-agent-monitor.service.in
SERVICE_DST := $(SYSTEMD_DIR)/$(SERVICE_NAME)

# Detect shell and determine rc file
SHELL_NAME := $(shell basename $$SHELL)
ifeq ($(SHELL_NAME),zsh)
	ifeq ($(wildcard $(HOME)/.zshrc.local),)
		SHELLRC := $(HOME)/.zshrc
	else
		SHELLRC := $(HOME)/.zshrc.local
	endif
else
	SHELLRC := $(HOME)/.bashrc
endif

.PHONY: all install uninstall check

all: check

check:
	@which inotifywait >/dev/null 2>&1 || (echo "Error: inotifywait not found. Install inotify-tools." && exit 1)
	@which ssh-add >/dev/null 2>&1 || (echo "Error: ssh-add not found. Install openssh-client." && exit 1)
	@echo "All dependencies found."

install: check
	@echo "Setting up systemd user service..."
	@mkdir -p $(SYSTEMD_DIR)
	@sed 's|@BINDIR@|$(BINDIR)|g' $(SERVICE_SRC) > $(SERVICE_DST)
	@systemctl --user daemon-reload
	@systemctl --user enable $(SERVICE_NAME)
	@systemctl --user restart $(SERVICE_NAME)
	@echo "Systemd service installed and started."
	@echo ""
	@echo "Setting up ~/.ssh/rc..."
	@if [ -e $(SSHRC) ]; then \
		if ! grep -q "$(BINDIR)/ssh-rc" $(SSHRC) 2>/dev/null; then \
			echo "" >> $(SSHRC); \
			echo "# Added by ssh-agent-monitor" >> $(SSHRC); \
			echo "\"$(BINDIR)/ssh-rc\"" >> $(SSHRC); \
			echo "Added ssh-agent-monitor/ssh-rc call to existing ~/.ssh/rc"; \
		else \
			echo "~/.ssh/rc already references ssh-agent-monitor/ssh-rc"; \
		fi; \
	else \
		mkdir -p $(dir $(SSHRC)); \
		echo '#!/bin/sh' > $(SSHRC); \
		echo '# Added by ssh-agent-monitor' >> $(SSHRC); \
		echo "\"$(BINDIR)/ssh-rc\"" >> $(SSHRC); \
		chmod +x $(SSHRC); \
		echo "Created ~/.ssh/rc"; \
	fi
	@echo ""
	@echo "Setting up shell configuration..."
	@if [ -f $(SHELLRC) ]; then \
		if ! grep -q "SSH_AUTH_SOCK.*XDG_RUNTIME_DIR.*ssh-auth-sock" $(SHELLRC); then \
			echo "" >> $(SHELLRC); \
			echo "# Added by ssh-agent-monitor" >> $(SHELLRC); \
			echo 'export SSH_AUTH_SOCK="$$XDG_RUNTIME_DIR/ssh-auth-sock"' >> $(SHELLRC); \
			echo "Added SSH_AUTH_SOCK export to $(SHELLRC)"; \
		else \
			echo "SSH_AUTH_SOCK already configured in $(SHELLRC)"; \
		fi \
	else \
		echo "Warning: $(SHELLRC) not found. Add this to your shell config:"; \
		echo '  export SSH_AUTH_SOCK="$$XDG_RUNTIME_DIR/ssh-auth-sock"'; \
	fi
	@echo ""
	@echo "Installation complete!"
	@echo "Restart your shell or run: source $(SHELLRC)"

uninstall:
	@echo "Stopping and disabling systemd service..."
	@-systemctl --user stop $(SERVICE_NAME) 2>/dev/null || true
	@-systemctl --user disable $(SERVICE_NAME) 2>/dev/null || true
	@rm -f $(SERVICE_DST)
	@systemctl --user daemon-reload
	@echo "Systemd service removed."
	@echo ""
	@echo "Cleaning up ~/.ssh/rc..."
	@if [ -f $(SSHRC) ] && grep -q "$(BINDIR)/ssh-rc" $(SSHRC) 2>/dev/null; then \
		if [ "$$(grep -c 'ssh-agent-monitor' $(SSHRC) 2>/dev/null)" = "2" ] && [ "$$(wc -l < $(SSHRC))" = "3" ]; then \
			rm $(SSHRC); \
			echo "Removed ~/.ssh/rc (created by us)"; \
		else \
			echo "~/.ssh/rc contains a line calling ssh-agent-monitor/ssh-rc"; \
			echo "Remove this line manually:"; \
			grep "$(BINDIR)/ssh-rc" $(SSHRC); \
		fi; \
	else \
		echo "~/.ssh/rc not modified by us"; \
	fi
	@echo ""
	@echo "Note: Shell config was not modified. Remove manually from $(SHELLRC):"
	@echo '  export SSH_AUTH_SOCK="$$XDG_RUNTIME_DIR/ssh-auth-sock"'
