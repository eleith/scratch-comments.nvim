# Prefer mason-installed tooling (local dev), fall back to PATH (CI).
MASON := $(HOME)/.local/share/nvim/mason/bin
tool = $(if $(wildcard $(MASON)/$(1)),$(MASON)/$(1),$(1))

STYLUA   := $(call tool,stylua)
LUACHECK := $(call tool,luacheck)
LUALS    := $(call tool,lua-language-server)

NVIM ?= nvim
BUILD := .build

.PHONY: all check test test-pending lint fmt fmt-check types clean

all: check

## check: everything CI runs
check: lint fmt-check types test

## test: run the passing suites, each in its own Neovim
test: PASSING := tests/smoke.lua
test:
	@fail=0; \
	for t in $(PASSING); do \
		printf '%-22s ' "$$t"; \
		out=$$($(NVIM) --headless --clean -u tests/minimal_init.lua \
			-c "lua local ok,e=pcall(dofile,'$$t') if not ok then io.write('FAIL: '..tostring(e)..'\n') end vim.cmd('qa!')" \
			2>&1 | grep -E '^(FAIL|[a-z]+: ok)' || true); \
		case "$$out" in \
			FAIL*) echo "$$out"; fail=1 ;; \
			*) echo "ok" ;; \
		esac; \
	done; \
	exit $$fail

## test-pending: suites that assert unimplemented behavior (Phase 1 target)
test-pending:
	@$(NVIM) --headless --clean -u tests/minimal_init.lua \
		-c "lua local ok,e=pcall(dofile,'tests/reflow.lua') if not ok then io.write('FAIL: '..tostring(e)..'\n') end vim.cmd('qa!')" \
		2>&1 | grep -E '^(FAIL|[a-z]+: ok)' || true

## lint: luacheck
lint:
	@$(LUACHECK) lua/ tests/ --no-color

## fmt: format in place
fmt:
	@$(STYLUA) lua/ tests/

## fmt-check: fail if unformatted
fmt-check:
	@$(STYLUA) --check lua/ tests/

## types: lua-language-server against the annotations
types:
	@mkdir -p $(BUILD)
	@$(NVIM) --headless -c 'lua io.write(vim.env.VIMRUNTIME)' -c 'qa!' 2>/dev/null > $(BUILD)/runtime
	@sed 's|"workspace.ignoreDir": \[".git"\]|"workspace.ignoreDir": [".git"], "workspace.library": ["'"$$(cat $(BUILD)/runtime)"'/lua"]|' \
		.luarc.json > $(BUILD)/luarc.json
	@$(LUALS) --check "$(CURDIR)/lua" --checklevel=Warning \
		--configpath="$(CURDIR)/$(BUILD)/luarc.json" --logpath="$(CURDIR)/$(BUILD)/luals" \
		| tail -5

clean:
	@rm -rf $(BUILD)
