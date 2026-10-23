# Publishing QuickeyDB 3.0.0

Prepared 23 October 2026. Pub.dev currently lists **1.2.0+8**; **3.0.0** was
available when checked. The major-version jump intentionally skips 2.0.0.
Release changes are committed locally at the maintainer’s request; this
preparation does not upload the package, push commits or create a release tag.

## Before publishing

- [ ] Review [CHANGELOG](../CHANGELOG.md) and [migration notes](MIGRATING_TO_3.md), including migration safeguards, encryption/key recovery and legacy database paths.
- [ ] Confirm 3.0.0 is intended and still available. The version-jump hint is expected; review it explicitly.
- [ ] Run the commands below; review minimum-SDK and native-platform CI separately.
- [ ] Review modified **and untracked** files and intentional deletions, then commit/push the intended release. Documentation links target main; merge/push the reviewed release there before publishing.
- [ ] Inspect the archive: library, license, README, changelog, guides, logo and standalone example must be present; builds, caches, local configuration and signing keys must be absent.
- [ ] Repeat the dry run from a clean committed checkout and resolve warnings.
- [ ] Confirm your pub.dev account is authorized to publish `quickeydb` and check the final name/version before upload.

## Package verification

```sh
cd /Users/kenzy/IdeaProjects/aflare-space/plugins/external/quickeydb
flutter pub get --no-example
flutter analyze --no-pub lib test example/quickeydb_example.dart
flutter test --no-pub
dart run example/quickeydb_example.dart
# SDK-bundled Dartdoc 9.0.6 has a known docImport crash; use a current tool.
dart pub global activate dartdoc ^9.0.11
dart pub global run dartdoc --output doc/api
git diff --check
flutter pub publish --dry-run
```

The standalone example generates a ready DAO without opening a database. Its
source is checked against the pub.dev example Markdown by the package tests.

## Full gallery verification

The repository gallery uses the sibling Activity checkout. It is a workspace app;
the QuickeyDB library and standalone example have no Activity dependency.

```sh
cd /Users/kenzy/IdeaProjects/aflare-space/plugins/external/quickeydb/example
flutter pub get
flutter analyze --no-pub
flutter test --no-pub
dart run tool/test_web.dart
flutter build web --no-pub --no-web-resources-cdn --no-wasm-dry-run
```

If needed, set `CHROME_EXECUTABLE` to your installed Chrome executable. Run builds
sequentially because native hooks share staging directories. Set real gift,
coffee and social links before deploying the gallery; defaults stay disabled.

## Archive decisions

`.pubignore` excludes nested output, private configuration and signing material.
The workspace-only `example/pubspec.yaml` is excluded so a package installation
does not attempt to resolve `../../Activity`. Gallery sources and intentional
SQLite worker/WASM files remain reference material. Clone the repositories to run
the complete gallery. `example/example.md` is the self-contained pub.dev example,
with runnable source in `example/quickeydb_example.dart`.

The supplied Q PNG is preserved in `assets/quickeydb.png`. Extracted gradient
samples are pink **#EC2182**, orange **#F38141** and yellow **#F8C612**; the gallery
uses pink as its default Material seed, with warm surfaces and orange/yellow
accent choices. Derived web icons use the same supplied image.

## Recorded local checks

The package resolves from an independent temporary copy with no sibling Activity
checkout. All 67 package tests pass, including the canonical workflow/source contracts. Gallery analysis is clean, all 13 host tests
and 4 Chrome worker tests pass, and the production web build succeeds. API docs
generated with Dartdoc 9.0.11 have zero warnings/errors across 45 libraries. The clean
copy's publishing dry run reports zero warnings and one intentional version-jump
hint; the compressed archive is approximately 1 MB. The accumulated source changes and obsolete-file deletions are recorded in the
local release commit, resolving their Git-state warnings.

## Remaining release gates

Publish from the clean committed source. If later edits appear, review and
commit the intended modifications/deletions before another dry run. The
intentional 1.x → 3.0.0 jump remains a version hint; it is not a validation warning.

Verify the Dart 3.9 / Flutter 3.35 floor and actual supported native targets in CI.
Local host/Chrome checks do not verify device signing, secure-storage entitlements,
SQLCipher factory integrations or recovery of application-managed encryption keys.
Review real schema upgrades and backup/key recovery for your application.

## Publish only after completing the checklist

```sh
cd /Users/kenzy/IdeaProjects/aflare-space/plugins/external/quickeydb
flutter pub publish
```

Review the CLI summary and complete authentication/confirmation yourself. After
uploading, check the version, README, example and API docs on
[pub.dev](https://pub.dev/packages/quickeydb), then tag the reviewed release commit
using your normal Git workflow.

The bundled documentation-tool crash is an [upstream Dartdoc issue](https://github.com/dart-lang/dartdoc/issues/4180); a temporary newer tool was used without changing the shared SDK.

See the official [publishing guide](https://dart.dev/tools/pub/publishing).

## Source and ignore review

Recursive Git/pub exclusions now cover nested build/cache/coverage output, local
SQLite files and sidecars, private environment/key configuration, and temporary
browser/API test fixtures. These patterns do not untrack already committed files.
Review previously tracked generated platform files with the release diff; no
existing source or index entries were removed automatically. Intentional worker/
WASM assets, logos, screenshots and copyable source remain part of the examples.

Final independent archive checks after the workflow update: dependency resolution,
analysis and the five documentation/recipe tests pass without sibling Activity.
Publishing validation reports zero warnings and the intentional 1.x → 3.0.0 hint.

## Git-state publishing warnings

A modified-file warning means committed source and on-disk files differ. Include
intended platform/configuration changes in the release commit; do not revert
working changes merely to silence validation. Use `git status --short` to check
both staged and unstaged changes, then review with `git diff` and `git diff --cached`.

The QuickeyDB preparation also contained 34 tracked files deleted from disk,
including obsolete screenshots, Gradle files superseded by Kotlin DSL and old
example/test templates. Pub reported these absent tracked paths in its
checked-in-but-ignored warning. Recording their intended deletions removes that
mismatch. Use `git ls-files -d` for missing tracked paths and
`git ls-files -ci --exclude-standard` for genuine tracked/ignored overlaps.
Keep upload exclusions in .pubignore; .gitignore does not untrack existing files.

A version-jump hint does not require --force or a version downgrade. Keep the
reviewed intended release version and complete the normal publishing confirmation.
