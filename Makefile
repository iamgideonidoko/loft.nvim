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

# Space-separated list of Neovim versions to test against locally.
# Override: make test-compat NVIM_TEST_VERSIONS="v0.10.3 v0.11.0"
NVIM_TEST_VERSIONS ?= v0.8.3 v0.9.5 v0.10.3 v0.11.0 nightly

test-compat: deps/mini.nvim
	@echo "Compatibility test  –  versions: $(NVIM_TEST_VERSIONS)"; \
	failed=""; \
	for v in $(NVIM_TEST_VERSIONS); do \
		printf "\n\033[1m── nvim %-12s ──\033[0m\n" "$$v"; \
		if ! bash scripts/download_nvim.sh "$$v" 2>&1; then \
			printf "\033[33mSKIP %-12s (download failed)\033[0m\n" "$$v"; \
			continue; \
		fi; \
		nvim_bin="deps/nvim-versions/$$v/bin/nvim"; \
		if "$$nvim_bin" --headless --noplugin -u scripts/minimal_init.vim \
				-c "luafile scripts/test_setup.lua" \
				-c "lua MiniTest.run()" \
				-c 'qa' 2>&1; then \
			printf "\033[32mPASS $$v\033[0m\n"; \
		else \
			printf "\033[31mFAIL $$v\033[0m\n"; \
			failed="$$failed $$v"; \
		fi; \
	done; \
	if [ -n "$$failed" ]; then \
		printf "\n\033[31mFailed versions:%s\033[0m\n" "$$failed"; exit 1; \
	else \
		printf "\n\033[32mAll versions passed.\033[0m\n"; \
	fi

deps/mini.nvim:
	@mkdir -p deps
	git clone --filter=blob:none https://github.com/echasnovski/mini.nvim $@
