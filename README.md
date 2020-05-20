# Cryptomator for iOS

## Building

### Install Dependencies

Install [CocoaPods](https://cocoapods.org/) if you haven't already.

```sh
pod install
```

### Create Secrets

If you are building with Xcode, create a `.cloud-access-secrets.sh` file in the root directory. Its contents should look something like this:

```sh
#!/bin/sh
export GOOGLE_DRIVE_CLIENT_ID=...
export GOOGLE_DRIVE_REDIRECT_URL=...
```

If you are building via a CI system, set these secret environment variables accordingly.

#### Integration Testing

If you are running integration tests, you have to set those secrets as well. The file is called `.integration-test-secrets.sh`, also put it in the root directory. Contents are:

```sh
#!/bin/sh
export GOOGLE_DRIVE_REFRESH_TOKEN=...
```

## Contributing

Install [SwiftFormat](https://github.com/nicklockwood/SwiftFormat/) if you haven't already.

The code will regularly be linted via SwiftFormat if you build the project. If the code is not formatted according to the rules, you will see warnings that you should fix.