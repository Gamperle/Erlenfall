# Project rules

## Track every unfixed problem

Always create a GitHub issue for every problem or limitation you find but don't fix immediately, without asking first. This covers anything found while testing, reading code, or reviewing. Check [existing issues](https://github.com/Gamperle/Erlenfall/issues) to avoid duplicates, and link the new issues when you report your work.

## Working on the game

- Follow [the design document](docs/GAME_DESIGN.md) and [the contribution guide](CONTRIBUTING.md).
- Work on a branch and open a pull request. The maintainer tests at each milestone.
- Run the smoke test before opening a pull request: `godot --headless --path . --script res://tests/smoke_test.gd`.
