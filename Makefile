# Tools come from PATH: mise locally, the nvim image in CI.
STYLUA ?= stylua
LUALS  ?= lua-language-server
NVIM   ?= nvim
BUILD  := .build

MINI_TEST_VERSION := v0.18.0
MINI_TEST := deps/mini.test-$(MINI_TEST_VERSION)

.PHONY: all check test lint fmt fmt-check clean

all: check

## check: everything CI runs
check: lint fmt-check test

## test: run the specs
test: $(MINI_TEST)
	@MINI_TEST=$(MINI_TEST) $(NVIM) --headless --clean -u tests/minit.lua -c "lua MiniTest.run()"

## deps: mini.test, cloned once per version
$(MINI_TEST):
	@git -c advice.detachedHead=false clone --quiet --depth 1 --branch $(MINI_TEST_VERSION) \
		https://github.com/nvim-mini/mini.test $@

## lint: lua-language-server diagnostics and type checking over lua/ and tests/
##
## Outside an editor nothing supplies Neovim's runtime types, so a build copy of
## .luarc.json adds $VIMRUNTIME/lua and mini.test. Output goes to a file, not a
## pipe, so make sees lua-language-server's exit status rather than the filter's.
lint: $(MINI_TEST)
	@mkdir -p $(BUILD)
	@$(NVIM) --headless --clean \
		-c 'lua local c = vim.json.decode(table.concat(vim.fn.readfile(".luarc.json"), "\n")); c["workspace.library"] = { vim.env.VIMRUNTIME .. "/lua", "$(MINI_TEST)/lua" }; vim.fn.writefile({ vim.json.encode(c) }, "$(BUILD)/luarc.json")' \
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
