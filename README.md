# Davat

Davat is an iPhone app for making custom invites with a layered design editor, collecting RSVPs, and running group fundraisers where guests split a cost. Invites are shared as a link that opens a web page or the app.

Status: early. The welcome screen and the core logic (models, fundraiser math, Venmo and Cash App links) exist; the backend is not connected yet.

## Run

Prerequisites: Xcode 27, an iOS 26 simulator, and XcodeGen (`brew install xcodegen`).

```sh
xcodegen generate
xcodebuild -project Davat.xcodeproj -scheme Davat \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build CODE_SIGNING_ALLOWED=NO
cd DavatKit && swift test
```

The stack is SwiftUI, a local Swift package (`DavatKit`), and XcodeGen.

## How it works

All logic that does not need UI lives in `DavatKit`, a Swift package that builds and tests on the command line without a simulator. It holds the invite, RSVP and design models, the fundraiser summary (goal, raised, progress), and the payment link builders. Money is stored as integer cents throughout.

An invite design is a background plus a list of layers (text, emoji, image, shape) positioned as fractions of the canvas, and decoding drops layers of a kind the running build does not recognize, so an older app can still open a design saved by a newer one. Fundraisers do not process payments; they open a prefilled Venmo or Cash App link and the host marks guests as paid.
