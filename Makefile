format:
	stylua lua/ --config-path=.stylua.toml

lint:
	luacheck lua/ --globals vim

gen_doc:
	nvim --headless -u scripts/minimal_init.vim -c "lua require('mini.doc').generate()" -c 'qa'
