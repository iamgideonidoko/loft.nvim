format:
	stylua lua/ tests/ --config-path=.stylua.toml

lint:
	luacheck lua/ tests/ --globals vim

gen_doc: deps/mini.nvim
	nvim --headless --noplugin -u scripts/minimal_init.vim -c "lua require('mini.doc').generate()" -c 'qa'

test: deps/mini.nvim
	nvim --headless --noplugin -u scripts/minimal_init.vim \
    -c "luafile scripts/test_setup.lua" \
    -c "lua MiniTest.run()" \
    -c 'qa'

deps/mini.nvim:
	@mkdir -p deps
	git clone --filter=blob:none https://github.com/echasnovski/mini.nvim $@
