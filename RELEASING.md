# Releasing

All four packages are published from this repo by pushing a git tag. The
[`release.yml`](.github/workflows/release.yml) workflow reads the tag prefix
and runs only the matching job.

| Package | Registry | Tag prefix | Example |
| --- | --- | --- | --- |
| `diver_flutter_annotation` | pub.dev | `flutter-annotation-v` | `flutter-annotation-v0.1.1` |
| `diver_flutter_builder` | pub.dev | `flutter-builder-v` | `flutter-builder-v0.1.6` |
| `diver_expo_builder` | npm (`@saas-to-bentley/diver-expo-builder`) | `expo-v` | `expo-v0.1.0` |
| `diver_android` | Maven Central (`io.github.saas-to-bentley:diver-android`) | `android-v` | `android-v0.1.0` |

The tag version must match the version in the package's manifest — `version:`
in `pubspec.yaml`, `"version"` in `package.json`, `version` in `build.gradle.kts`.
Bump the manifest first, commit, then tag that commit.

```sh
# Example: releasing diver_expo_builder 0.1.1
# 1. Bump the version in diver_expo_builder/package.json and add a CHANGELOG entry.
# 2. Commit.
git commit -am "diver_expo_builder 0.1.1"
# 3. Tag and push.
git tag expo-v0.1.1
git push origin main expo-v0.1.1
```

## One-time setup per registry

The workflow assumes the setup below is done. Do this once, then every tag
push publishes without any manual steps.

### pub.dev (Flutter packages)

Uses [automated publishing](https://dart.dev/tools/pub/automated-publishing)
via GitHub Actions OIDC — no secret needed on GitHub. **The first release of
each package must still be published manually** (from your dev machine with
`dart pub publish`) so that the package exists on pub.dev and you can
configure the automated-publishing mapping.

For each of `diver_flutter_annotation` and `diver_flutter_builder`, after the
first manual publish:

1. Go to https://pub.dev/packages/<package>/admin.
2. Under **Automated publishing → GitHub Actions**, enable it and set:
   - Repository: `SaaS-To-Bentley/diver_builders`
   - Tag pattern: `flutter-annotation-v{{version}}` (or `flutter-builder-v{{version}}`)
3. Save.

From then on, pushing a matching tag publishes automatically — the workflow's
`id-token: write` permission lets `dart pub publish` mint a short-lived OIDC
token that pub.dev exchanges for publish rights.

### npm

The workflow uses a classic npm token stored as a GitHub secret.

1. Create an npm access token at https://www.npmjs.com/settings/<user>/tokens
   — **Automation** type (bypasses 2FA, required for CI).
2. Add it to the repo as `NPM_TOKEN`:
   https://github.com/SaaS-To-Bentley/diver_builders/settings/secrets/actions
3. Make sure the `@saas-to-bentley` scope exists on npm (create the org if you
   haven't already) and that your account can publish under it.

The `publishConfig` in `package.json` handles `access: public` and provenance;
the workflow requests OIDC (`id-token: write`) so npm attaches a provenance
attestation to the tarball.

### Maven Central

Publishing uses the [vanniktech maven-publish plugin](https://vanniktech.github.io/gradle-maven-publish-plugin/)
against the Central Portal (https://central.sonatype.com), the modern
successor to OSSRH.

**Namespace verification.** Register `io.github.saas-to-bentley` as your
namespace under the Central Portal. GitHub-based verification is automatic:
the portal checks that `github.com/saas-to-bentley` exists.

**Portal credentials.** Under Central Portal → Account, generate a user
token — it produces a username and password. Add both to GitHub secrets:

- `MAVEN_CENTRAL_USERNAME` — the token username
- `MAVEN_CENTRAL_PASSWORD` — the token password

**Signing.** Maven Central requires every artifact to be GPG-signed.

```sh
# Generate a GPG key (once).
gpg --full-generate-key
# List keys to find the ID.
gpg --list-secret-keys --keyid-format=long
# Export the ASCII-armored private key.
gpg --export-secret-keys --armor <KEY_ID> > signing-key.asc
# Publish the public half to a keyserver so Central can verify it.
gpg --keyserver keyserver.ubuntu.com --send-keys <KEY_ID>
```

Add to GitHub secrets:

- `SIGNING_KEY` — the full contents of `signing-key.asc` (multiline)
- `SIGNING_KEY_PASSWORD` — the passphrase you set when generating the key

Delete `signing-key.asc` from your machine after uploading it.

## Manual release (fallback)

If the workflow is broken or you need to release without pushing to `main`:

```sh
# Flutter packages
cd diver_flutter_annotation && dart pub publish
cd diver_flutter_builder && dart pub publish

# npm
cd diver_expo_builder && npm run build && npm publish

# Maven Central
cd diver_android && ./gradlew publishToMavenCentral --no-configuration-cache
```

The manifest version is authoritative; the git tag is just what triggers the
workflow. If you publish manually, still tag the commit after so the history
matches what's on the registries.
