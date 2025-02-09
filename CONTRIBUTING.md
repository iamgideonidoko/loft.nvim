# Contributing

Thank you for your willingness to contribute to `loft.nvim`. It means a lot!

You can make contributions in the following ways:

- **Mention it** somehow to help reach broader audience. This helps a lot.
- **Create a GitHub issue**. It can be one of the following types:
  - **Bug report**. Describe your actions in a reproducible way along with their effect and what you expected should happen. Before making one, please make your best efforts to:
    - Make sure that it is not an intended behavior, i.e. not described in documentation as such.
    - Make sure that it was not reported before, i.e. there is no bug report already created (no matter open or closed).
  - **Feature request**. A concise and justified description of what one or several modules should be able to do. Before making one, please make your best efforts to make sure that it is not a feature that won't get implemented.
- **Create a pull request (PR)**. It can be one of the following types:
  - **Code related**. For example, fix a bug or implement a feature. **Before even starting one, please make sure that it is aligned with project vision and goals**. The best way to do so is to receive positive feedback from maintainer on your initiative in one of the GitHub issues (existing or created by you). Please, make sure to regenerate latest help file and that all tests pass (see later sections).
  - **Documentation related**. For example, fix typo/wording in 'README.md', code comments or annotations (which are used to generate Neovim documentation; see later section). Feel free to make these without creating a GitHub issue.

All well-intentioned, polite, and respectful contributions are always welcome! Thanks for reading this!

## Setup

Using `lazy.nvim`:

```lua
return {
  dir = "~/path/to/loft.nvim",
  dev = true,
  config = true,
}
```

Using bare Neovim instance:

```sh
nvim -u scripts/minimal_init.vim
```

## Commit messages

- Try to make commit message as concise as possible while giving enough information about nature of a change. Think about whether it will be easy to understand in one year time when browsing through commit history.

- Use [Conventional commits](https://www.conventionalcommits.org/en/v1.0.0/) style:

  - Messages should have the following structure:

    ```
    <type>[optional scope][!]: <description>
    <empty line>
    [optional body]
    <empty line>
    [optional footer(s)]
    ```

  - `<type>` is **mandatory** and can be one of:
    - `ci` - change in how automation (GitHub actions, dual distribution scripts, etc.) is done.
    - `docs` - change in user facing documentation (help, README, CONTRIBUTING, etc.).
    - `feat` - adding new user facing feature.
    - `fix` - resolving user facing issue.
    - `refactor` - change in code or documentation that should not affect users.
    - `style` - change in convention of how something should be done (formatting, wording, etc.) and its effects.
    - `test` - change in tests.
      For temporary commits which later should be squashed (when working on PR, for example), use `fixup` type.
  - `[optional scope]`, if present, should be done in parenthesis `()`. If commit changes single module (as it usually should), using scope with module name is **mandatory**. If commit enforces something for all modules, use `ALL` scope.
  - Breaking change, if present, should be expressed with `!` before `:`.
  - `<description>` is a change overview in imperative, present tense ("change" not "changed" nor "changes"). Should result into first line under 72 characters. Should start with not capitalized word and NOT end with sentence ending punctuation (i.e. one of `.,?!;`).
  - `[optional body]`, if present, should contain details and motivation about the change in plain language. Should be formatted to have maximum 80 characters in line.
  - `[optional footer(s)]`, if present, should be instruction(s) to Git or Github. Use "Resolve #xxx" on separate line if this commit resolves issue or PR.

Examples:

```
feat(deps): add folds in update confirmation buffer
```

```
fix(jump): make operator not delete one character if target is not found

One main goal is to do that in a dot-repeatable way, because this is very
likely to be repeated after an unfortunate first try.

Resolve #688
```

```
refactor(bracketed): do not source 'vim.treesitter' on `require()`

Although less explicit, this considerably reduces startup footprint of
'mini.bracketed' in isolation.
```

```
feat(hues)!: update verbatim text to be distinctive
```

```
test(ALL): update screenshots to work on Nightly
```

## Generating help file

If your contribution updates annotations used to generate help file, please regenerate it. You can make this with one of the following (assuming current directory being project root):

- From command line execute `make gen_doc`.
- Inside Neovim instance run `:lua require('mini.doc').generate()`.

## Testing

If your contribution updates code, please make sure that it doesn't break existing tests. If it adds new functionality or fixes a recognized bug, add new test case(s). There are two ways of running tests:

- From command line:
  - Execute `make test` to run all tests (with `nvim` as executable).
- Inside Neovim instance execute `:lua require('mini.test').setup(); MiniTest.run()` to run all tests or `:lua require('mini.test').setup(); MiniTest.run_file()` to run tests only from current buffer.

This plugin uses 'mini.test' to manage its tests. For a more hands-on introduction, see its [testing guide](https://github.com/echasnovski/mini.nvim/blob/main/TESTING.md).

**Notes**:

In case there is some test breaking which reasonably should not, rerun that test (or the whole file) at least several times.

- Advice for writing more robust tests:
  - To test asynchronous or slow execution, use common `sleep()` test helper. For a more robust testing code, **never** directly use numbers to compute sleep time. Use precomputed time delay constants, which should always take into account different testing OSs (like be bigger on Windows, etc.).
  - Take into account that Windows uses "\" as default path separator instead of Unix "/". This should be accounted either in module's code (preferably) or in test files (for example, by computing path separator and relying on it).

## Formatting and Linting

Before making changes to code, please:

- [Install StyLua for formatting](https://github.com/JohnnyMorganz/StyLua#installation).
- [Install Luacheck for linting](https://github.com/mpeterv/luacheck?tab=readme-ov-file#installation).
- Format with `make format`
- Lint check with `make lint`
