# SwiftyDropbox

A Swift SDK for integrating with the Dropbox API v2 (preview version).

## Setup

To get started with SwiftyDropbox, we recommend you add it to your project using CocoaPods.

1. Install CocoaPods:
```sudo gem install cocoapods```

1. If you've never used Cocoapods before, run:
```pod setup```

1. In your project directory, create a new file and call it "Podfile". Add the following text to the file:
```
  platform :ios, '8.0'
  use_frameworks!

  pod 'SwiftyDropbox', :git => 'git@github.com:dropbox/SwiftyDropbox.git', :branch => 'swift-2.0'
``` 

1. From the project directory, install the SwiftyDropbox SDK with:
```pod install```

## Creating an application

You need to create an Dropbox Application to make API requests.

- Go to https://dropbox.com/developers/apps.

## Obtaining an access token

All requests need to be made with an OAuth 2 access token. To get started, once
you've created an app, you can go to the app's console and generate an access
token for your own Dropbox account.

## Examples

* [PhotoWatch](https://github.com/dropbox/PhotoWatch) - View photos from your Dropbox on your Apple Watch.

## Read more

Read more about SwiftyDropbox on our [developer blog](https://blogs.dropbox.com/developers/2015/05/try-out-swiftydropbox-the-new-swift-sdk-for-dropbox-api-v2/).
