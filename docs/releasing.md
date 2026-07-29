# Release Process

## Quality gates

1. Update `package.json` and `extension/manifest.json` to the same semantic version.
2. Move relevant entries from `Unreleased` into a versioned `CHANGELOG.md` section.
3. Run:

   ```sh
   make lint
   make test
   make doctor
   ```

4. Complete `docs/manual-test-plan.md` against Brave Stable.
5. Run `make package` and verify the generated SHA-256 checksum.
6. Confirm the worktree is clean and CI is green.

## Publishing

Create and push a signed tag matching the project version:

```sh
git tag -s vX.Y.Z -m "Recent Tab Toggle vX.Y.Z"
git push origin vX.Y.Z
```

The release workflow refuses a mismatched tag, reruns the test suite, creates a deterministic extension archive, and publishes the archive with its checksum.

## Native helper policy

Releases remain source-installed until an Apple Developer ID is available. Do not attach unsigned native helper binaries. Once signing is available, add universal Intel/Apple-silicon compilation, hardened-runtime signing, notarization, stapling, and signature verification to the release workflow before publishing native artifacts.

## Rollback

- Do not move or replace an existing tag.
- Mark a broken GitHub release as a pre-release and publish a patch version.
- Keep native messaging protocol changes backwards-compatible across at least one minor version because running helper processes may outlive an extension update temporarily.
