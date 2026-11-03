DBT_FT_NVIM ?= nvim
# Overridable, to reuse an nvim-treesitter checkout or a parser directory.
export NVIM_TREESITTER ?= $(CURDIR)/.tests/nvim-treesitter
export DBT_FT_TS_DIR ?= $(CURDIR)/.tests/site
PARSER_DIR := $(DBT_FT_TS_DIR)/parser
PARSERS := $(addprefix $(PARSER_DIR)/,jinja.so jinja_inline.so sql.so)

.PHONY: format lint test

format:
	stylua .
	ts_query_ls format queries
	oxfmt

lint: $(PARSERS)
	selene .
	VIMRUNTIME=$$($(DBT_FT_NVIM) --clean --headless --cmd 'lua io.write(vim.env.VIMRUNTIME)' --cmd 'qa!') \
	  lua-language-server --check . --checklevel=Warning
	scripts/check-queries

test: $(PARSERS)
	$(DBT_FT_NVIM) --clean -l tests/dbt_ft_spec.lua

# Keeps the parser build and the tests out of the user's own Neovim data.
test $(PARSERS): export XDG_CACHE_HOME := $(CURDIR)/.tests/cache
test $(PARSERS): export XDG_CONFIG_HOME := $(CURDIR)/.tests/config
test $(PARSERS): export XDG_DATA_HOME := $(CURDIR)/.tests/data
test $(PARSERS): export XDG_STATE_HOME := $(CURDIR)/.tests/state

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
