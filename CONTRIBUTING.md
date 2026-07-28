# Contributing

Contributions are welcome. Keep the project focused on immediate two-tab toggling; broader MRU switchers should begin with a proposal rather than silently changing the product semantics in `CONTEXT.md`.

## Setup

Requirements are macOS 13+, Node.js 20+, Swift 6+, and Brave Stable.

```sh
make test
make install
```

## Development rules

- Use the canonical language in `CONTEXT.md`.
- Add behavioral tests before implementation changes.
- Keep the extension free of host permissions and runtime dependencies.
- Keep native standard output reserved for Chromium protocol frames.
- Add an ADR only for hard-to-reverse, non-obvious trade-offs—not routine implementation choices.
- Update `CHANGELOG.md` for user-visible changes.

## Pull requests

A pull request should include:

1. The user-visible scenario and expected behavior.
2. Tests covering the behavior or a reason testing is impractical.
3. Privacy, permission, and multi-profile impact.
4. Documentation updates where applicable.

Run `make test` before submission. Native UI/hotkey changes should also be exercised manually on Brave Stable.
