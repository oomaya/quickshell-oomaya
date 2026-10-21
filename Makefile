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

all: tools/dwm-quickshell-state-bin tools/mv-shim

tools/dwm-quickshell-state-bin: tools/dwm-quickshell-state.c
	$(CC) $(CFLAGS) -o $@ $< -lX11

tools/mv-shim: tools/mv-shim.c
	$(CC) $(CFLAGS) -o $@ $<

clean:
	rm -f tools/dwm-quickshell-state-bin tools/mv-shim

install: all
	@echo "==> Installing Quickshell configuration to $(CFG_DIR)/quickshell..."
	mkdir -p "$(CFG_DIR)/quickshell"
	cp -aL --no-preserve=ownership quickshell/. "$(CFG_DIR)/quickshell/"
	@echo "==> Installing helper scripts to $(BIN_DIR)..."
	mkdir -p "$(BIN_DIR)"
	install -Dm755 $(SCRIPTS) "$(BIN_DIR)/"
	install -Dm755 tools/dwm-quickshell-state-bin "$(BIN_DIR)/dwm-quickshell-state-bin"
	@if ! /bin/mv --help 2>&1 | grep -q -- '--exchange'; then \
		echo "==> Coreutils < 9.5 detected; installing mv shim to $(BIN_DIR)..."; \
		install -Dm755 tools/mv-shim "$(BIN_DIR)/mv"; \
	fi

uninstall:
	@echo "==> Removing Quickshell configuration..."
	rm -rf "$(CFG_DIR)/quickshell"
	@echo "==> Removing helper scripts from $(BIN_DIR)..."
	for s in $(notdir $(SCRIPTS)) dwm-quickshell-state-bin; do \
		rm -f "$(BIN_DIR)/$$s"; \
	done
	@if [ -f "$(BIN_DIR)/mv" ]; then \
		if "$(BIN_DIR)/mv" --help 2>&1 | grep -q 'renameat2'; then \
			rm -f "$(BIN_DIR)/mv"; \
		fi; \
	fi

fixtures:
	@if [ -d "../dwm-oomaya" ]; then \
		echo "==> Ensuring test fixtures from ../dwm-oomaya..."; \
		if [ -L config ] && [ "$$(readlink config)" = "." ]; then rm -f config; fi; \
		mkdir -p config; \
		for f in themes.toml hotkeys.toml window-rules.toml; do \
			[ -e "config/$$f" ] || cp "../dwm-oomaya/config/$$f" "config/$$f" 2>/dev/null || true; \
		done; \
		[ -e "config/quickshell" ] || ln -sf "../quickshell" "config/quickshell"; \
		for s in dwm-packages.sh dwm-session-launch dwm-panel-settings dwm-lock dwm-system-health dwm-settings-theme check-deps.sh; do \
			[ -e "bin/$$s" ] || ln -sf "../../dwm-oomaya/scripts/$$s" "bin/$$s" 2>/dev/null || cp "../dwm-oomaya/scripts/$$s" "bin/$$s"; \
		done; \
		[ -e "scripts" ] || ln -sf bin scripts; \
		[ -e "docs" ] || ln -sf ../dwm-oomaya/docs docs; \
		[ -e "dwm.c" ] || ln -sf ../dwm-oomaya/dwm.c dwm.c; \
		[ -e "config.mk" ] || ln -sf ../dwm-oomaya/config.mk config.mk; \
		[ -e "config.def.h" ] || ln -sf ../dwm-oomaya/config.def.h config.def.h; \
	fi

check: all fixtures
	@echo "==> Running Quickshell unit and integration test suite..."
	@status=0; \
	for t in tests/test-quickshell*.sh; do \
		echo "Running $$t..."; \
		rc=0; \
		$$t || rc=$$?; \
		if [ $$rc -eq 77 ]; then \
			continue; \
		elif [ $$rc -ne 0 ]; then \
			status=$$rc; \
		fi; \
	done; \
	exit $$status

.PHONY: all clean install uninstall check fixtures
