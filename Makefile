CC ?= gcc
CFLAGS ?= -std=c99 -pedantic -Wall -Wextra -Werror -O2 -g
PREFIX ?= /usr/local
USER_HOME ?= $(HOME)
CFG_DIR ?= $(USER_HOME)/.config
BIN_DIR ?= $(USER_HOME)/.local/bin

SCRIPTS = \
	bin/dwm-quickshell-launcher \
	bin/dwm-quickshell-controls \
	bin/dwm-quickshell-controlcenter \
	bin/dwm-quickshell-network \
	bin/dwm-quickshell-pointer \
	bin/dwm-quickshell-state \
	bin/dwm-quickshell-version-check \
	bin/quickshell-qmllint

all: tools/dwm-quickshell-state-bin

tools/dwm-quickshell-state-bin: tools/dwm-quickshell-state.c
	$(CC) $(CFLAGS) -o $@ $< -lX11

clean:
	rm -f tools/dwm-quickshell-state-bin

install: all
	@echo "==> Installing Quickshell configuration to $(CFG_DIR)/quickshell..."
	mkdir -p "$(CFG_DIR)/quickshell"
	cp -aL --no-preserve=ownership quickshell/. "$(CFG_DIR)/quickshell/"
	@echo "==> Installing helper scripts to $(BIN_DIR)..."
	mkdir -p "$(BIN_DIR)"
	install -Dm755 $(SCRIPTS) "$(BIN_DIR)/"
	install -Dm755 tools/dwm-quickshell-state-bin "$(BIN_DIR)/dwm-quickshell-state-bin"

uninstall:
	@echo "==> Removing Quickshell configuration..."
	rm -rf "$(CFG_DIR)/quickshell"
	@echo "==> Removing helper scripts from $(BIN_DIR)..."
	for s in $(notdir $(SCRIPTS)) dwm-quickshell-state-bin; do \
		rm -f "$(BIN_DIR)/$$s"; \
	done

check: all
	@echo "==> Running Quickshell unit and integration test suite..."
	@status=0; \
	for t in tests/test-quickshell*.sh; do \
		echo "Running $$t..."; \
		$$t || status=$$?; \
	done; \
	exit $$status

.PHONY: all clean install uninstall check
