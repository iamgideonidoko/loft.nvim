format:
	stylua lua/ --config-path=.stylua.toml

lint:
	luacheck lua/ --globals vim

gen_doc:
	nvim --headless --noplugin -u scripts/minimal_init.vim -c "lua require('mini.doc').generate()" -c 'qa'

test:
	nvim --headless --noplugin -u scripts/minimal_init.vim \
    -c "luafile scripts/test_setup.lua" \
    -c "lua MiniTest.run()" \
    -c 'qa'
