# Each tool is its latest release. Everything lands in .deps except Neovim,
# which is DBT_FT_NVIM or the nvim on PATH.

DEPS := .deps
BIN := $(DEPS)/bin
TOOLS := $(addprefix $(BIN)/,actionlint lua-language-server oxfmt selene shellcheck shfmt stylua ts_query_ls)
# Ahead of PATH, so a local run uses the same tools as CI.
export PATH := $(CURDIR)/$(BIN):$(PATH)

DBT_FT_NVIM ?= nvim
# Overridable, to reuse an nvim-treesitter checkout or a parser directory.
export NVIM_TREESITTER ?= $(CURDIR)/$(DEPS)/nvim-treesitter
export DBT_FT_TS_DIR ?= $(CURDIR)/$(DEPS)/site
PARSER_DIR := $(DBT_FT_TS_DIR)/parser
PARSERS := $(addprefix $(PARSER_DIR)/,jinja.so jinja_inline.so sql.so)

.PHONY: deps format lint parsers test update-deps

deps: $(TOOLS)

parsers: $(PARSERS)

# make keeps a fetched tool however old it gets.
update-deps:
	rm -rf $(DEPS)
	$(MAKE) deps

format: deps
	stylua .
	shfmt --write scripts
	ts_query_ls format queries
	oxfmt

lint: deps $(PARSERS)
	selene .
	shellcheck scripts/*
	actionlint
	VIMRUNTIME=$$($(DBT_FT_NVIM) --clean --headless --cmd 'lua io.write(vim.env.VIMRUNTIME)' --cmd 'qa!') \
	  lua-language-server --check . --checklevel=Warning
	scripts/check-queries

test: $(PARSERS)
	$(DBT_FT_NVIM) --clean -l tests/dbt_ft_spec.lua

# Keeps the parser build and the tests out of the user's own Neovim data.
test $(PARSERS): export XDG_CACHE_HOME := $(CURDIR)/$(DEPS)/xdg/cache
test $(PARSERS): export XDG_CONFIG_HOME := $(CURDIR)/$(DEPS)/xdg/config
test $(PARSERS): export XDG_DATA_HOME := $(CURDIR)/$(DEPS)/xdg/data
test $(PARSERS): export XDG_STATE_HOME := $(CURDIR)/$(DEPS)/xdg/state

$(NVIM_TREESITTER):
	git clone --quiet --depth 1 https://github.com/nvim-treesitter/nvim-treesitter $@

# One install builds all three, so the other two hang off jinja.so and make -j
# runs it once. Forced, as nvim-treesitter treats a language with queries as
# installed.
$(PARSER_DIR)/jinja_inline.so $(PARSER_DIR)/sql.so: $(PARSER_DIR)/jinja.so
$(PARSER_DIR)/jinja.so: | $(NVIM_TREESITTER)
	$(DBT_FT_NVIM) --clean --headless --cmd "set rtp^=$(NVIM_TREESITTER)" \
	  -c "lua require('nvim-treesitter').setup({ install_dir = vim.env.DBT_FT_TS_DIR })" \
	  -c "lua require('nvim-treesitter').install({ 'jinja', 'jinja_inline', 'sql' }, { force = true }):wait(300000)" \
	  -c qa

$(TOOLS): | $(BIN)

$(BIN):
	mkdir -p $@

$(BIN)/%:
	scripts/fetch $(src) $(DEPS)/$*
	install -m 755 $(DEPS)/$*/$(or $(member),$*) $@
	rm -rf $(DEPS)/$*

# Regexes, since each tool spells the platform its own way.
os := $(if $(filter Darwin,$(shell uname -s)),(darwin|macos),linux)
arch := $(if $(filter arm64 aarch64,$(shell uname -m)),(aarch64|arm64),(x86_64|amd64|x64))

$(BIN)/actionlint: src = rhysd/actionlint '^actionlint_[0-9.]+_$(os)_$(arch)\.tar\.gz$$'
$(BIN)/selene: src = Kampfkarren/selene '^selene-[0-9.]+-$(os)\.zip$$'
$(BIN)/shellcheck: src = koalaman/shellcheck '^shellcheck-v[0-9.]+\.$(os)\.$(arch)\.tar\.gz$$'
$(BIN)/shellcheck: member = shellcheck-*/shellcheck
$(BIN)/shfmt: src = mvdan/sh '^shfmt_v[0-9.]+_$(os)_$(arch)$$'
$(BIN)/shfmt: member = shfmt_*
$(BIN)/stylua: src = JohnnyMorganz/StyLua '^stylua-$(os)-$(arch)\.zip$$'
$(BIN)/ts_query_ls: src = ribru17/ts_query_ls '^ts_query_ls-$(arch)-[a-z]+-$(os)(-gnu)?\.tar\.gz$$'

# It finds its scripts beside its own binary, so it stays in its tree.
$(BIN)/lua-language-server:
	scripts/fetch LuaLS/lua-language-server '^lua-language-server-[0-9.]+-$(os)-$(arch)\.tar\.gz$$' $(DEPS)/luals
	printf '#!/bin/sh\nexec "$${0%%/*}/../luals/bin/lua-language-server" "$$@"\n' >$@
	chmod 755 $@

$(BIN)/oxfmt:
	npm install --global --silent --prefix $(DEPS) oxfmt@latest
