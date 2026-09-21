# Tools come from PATH: mise locally (see mise.toml), the install steps in CI.
# Override on the command line, e.g. `make lint LUALS=/path/to/lua-language-server`.
STYLUA ?= stylua
LUALS  ?= lua-language-server
NVIM   ?= nvim
BUILD  := .build

.PHONY: all check test lint fmt fmt-check clean

all: check

## check: everything CI runs
check: lint fmt-check test

## test: run each suite in its own Neovim
test: SUITES := tests/smoke.lua tests/reflow.lua tests/orphans.lua
test:
	@fail=0; \
	for t in $(SUITES); do \
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

## lint: lua-language-server diagnostics and type checking over lua/ and tests/
##
## .luarc.json is shared with the editor. CI has no editor to supply Neovim's
## runtime types, so add $VIMRUNTIME/lua as a library in a build copy.
## lua-language-server's exit status is kept: the output is saved to a file
## rather than piped, because a pipe would report the filter's status instead.
lint:
	@mkdir -p $(BUILD)
	@$(NVIM) --headless --clean \
		-c 'lua local c = vim.json.decode(table.concat(vim.fn.readfile(".luarc.json"), "\n")); c["workspace.library"] = { vim.env.VIMRUNTIME .. "/lua" }; vim.fn.writefile({ vim.json.encode(c) }, "$(BUILD)/luarc.json")' \
		-c 'qa!'
	@$(LUALS) --check "$(CURDIR)" --checklevel=Warning \
		--configpath="$(CURDIR)/$(BUILD)/luarc.json" --logpath="$(CURDIR)/$(BUILD)/luals" \
		> $(BUILD)/lint.log 2>&1; \
	status=$$?; \
	sed -E 's/\x1b\[[0-9;]*m//g' $(BUILD)/lint.log | tr '\r' '\n' \
		| grep -E '\.lua:[0-9]+|Diagnosis|problem' || true; \
	exit $$status

## fmt: format in place
fmt:
	@$(STYLUA) lua/ tests/

## fmt-check: fail if unformatted
fmt-check:
	@$(STYLUA) --check lua/ tests/

clean:
	@rm -rf $(BUILD)
