# Cryptomator for iOS

[![Build](https://github.com/cryptomator/ios/actions/workflows/build.yml/badge.svg)](https://github.com/cryptomator/ios/actions/workflows/build.yml)
[![Twitter](https://img.shields.io/badge/twitter-@Cryptomator-blue.svg?style=flat)](http://twitter.com/Cryptomator)
[![Crowdin](https://badges.crowdin.net/cryptomator/localized.svg)](https://translate.cryptomator.org/)
[![Community](https://img.shields.io/badge/help-Community-orange.svg)](https://community.cryptomator.org)

Cryptomator offers multi-platform transparent client-side encryption of your files in the cloud.

This is the repository for the new iOS app of Cryptomator, which has been rewritten from the ground up and is currently in a beta phase.

Try it out for free via TestFlight: https://testflight.apple.com/join/WMtYSrzD

If you're looking for the current App Store version and would like to report an issue, check out the other repository: https://github.com/cryptomator/cryptomator-ios

## Building

### Create Secrets

If you are building with Xcode, create a `.cloud-access-secrets.sh` file in the root directory. Its contents should look something like this:

```sh
#!/bin/sh
export DROPBOX_APP_KEY=...
export GOOGLE_DRIVE_CLIENT_ID=...
export GOOGLE_DRIVE_REDIRECT_URL_SCHEME=...
export ONEDRIVE_CLIENT_ID=...
export ONEDRIVE_REDIRECT_URI_SCHEME=...
```

And then run `./create-cloud-access-secrets-file.sh` once. Of course, if you change the secrets, you have to run that script again.

If you are building via a CI system, set these secret environment variables accordingly.

## Contributing

Please read our [contribution guide](.github/CONTRIBUTING.md), if you would like to report a bug, ask a question or help us with coding.

This project uses [SwiftFormat](https://github.com/nicklockwood/SwiftFormat) and [SwiftLint](https://github.com/realm/SwiftLint) to enforce code style and conventions. Install these tools if you haven't already.

Please make sure that your code is correctly formatted and passes linter validations. The easiest way to do that is to set up a pre-commit hook. Create a file at `.git/hooks/pre-commit` with this content:

```sh
./Scripts/process.sh --staged
exit $?
```

And make your pre-commit hook executable:

```sh
chmod +x .git/hooks/pre-commit
```

## Code of Conduct

Help us keep Cryptomator open and inclusive. Please read and follow our [Code of Conduct](.github/CODE_OF_CONDUCT.md).

## License

Distributed under the GPLv3. See the LICENSE file for more info.
