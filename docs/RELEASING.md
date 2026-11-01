# Signed and notarized macOS releases

The local development build stays ad-hoc signed. A separate release directory
contains the Developer ID signed app and its notarization results.

Prerequisites in the normal macOS login session:

- A valid **Developer ID Application** certificate and its private key for team
  `5UXXXESGMK` in the user's Keychain.
- Notarization credentials stored under the Keychain profile `notary`.
- Xcode command-line tools and access to Apple's signing and notary services.

The output directory is selected from the version in `Resources/Info.plist`.
For 0.2.1 it is `build/releases/0.2.1`; earlier artifacts in `build/release`
are preserved.

From the repository root:

```sh
./scripts/release.sh
```

The script builds the universal application, signs a separate release copy with
hardened runtime and a secure timestamp, verifies the team, submits it to Apple,
requires an Accepted result, staples the ticket, and checks Gatekeeper. It then
creates the final ZIP **after** stapling.

Distribute `build/releases/VERSION/Abadia-macOS-notarized.zip`. The adjacent signature,
submission receipt, Apple log, and SHA-256 checksum provide release evidence.
Do not distribute the intermediate `Abadia-notarization-upload.zip`.

Optional overrides: `RELEASE_DIR`, `TEAM_ID`, `NOTARY_PROFILE`, and `SIGNING_IDENTITY` (a
certificate fingerprint). Credentials are read directly from Keychain; the
script does not accept or print passwords.

If a submission times out, inspect `build/releases/VERSION/notarization.json` for its ID.
Check the existing job instead of submitting the same binary again:

```sh
xcrun notarytool info SUBMISSION_ID --keychain-profile notary
xcrun notarytool log SUBMISSION_ID --keychain-profile notary build/releases/VERSION/notarization-log.json
```

After an existing job becomes Accepted, staple and verify the existing release
app, then package that app again. Move the completed `build/releases/VERSION` directory
aside before building another release; never rebuild or re-sign a submitted app
while waiting for its ticket.

Apple's reference: [Notarizing macOS software before distribution](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution).

## Published release evidence

v0.2.0 was accepted on 2026-11-01. Submission:
`cfea6dea-da27-4c90-8034-44c930c3e61b`. The maintainer's local release run
reported successful stapling, ticket validation, and Gatekeeper approval with
`source=Notarized Developer ID`. The distribution ZIP SHA-256 is
`14668875c59b0088d97c781ae43e8973ba04ce403b13ebd0cc0bfb4a92a2cb81`.

The submitted archive's checksum matches Apple's [Accepted log](releases/v0.2.0-notarization.json),
and the distributed app's submitted files match that archive. Do not replace the
release asset with an ad-hoc development build.
