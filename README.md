# Davat

Davat is an iPhone app for making custom invites with a layered design editor, collecting RSVPs, and running group fundraisers where guests split a cost. Invites are shared as a link that opens a web page or the app.

Status: early. The welcome screen and the core logic (models, fundraiser math, Venmo and Cash App links) exist; the backend is not connected yet.

## Run

Prerequisites: Xcode 27, an iOS 26 simulator, and XcodeGen (`brew install xcodegen`).

```sh
xcodegen generate
xcodebuild -project Davat.xcodeproj -scheme Davat \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' build CODE_SIGNING_ALLOWED=NO
cd DavatKit && swift test
```

The stack is SwiftUI, a local Swift package (`DavatKit`), and XcodeGen.

## How it works

All logic that does not need UI lives in `DavatKit`, a Swift package that builds and tests on the command line without a simulator. It holds the invite, RSVP and design models, the fundraiser summary (goal, raised, progress), and the payment link builders. Money is stored as integer cents throughout.

An invite design is a background plus a list of layers (text, emoji, image, shape) positioned as fractions of the canvas, and decoding drops layers of a kind the running build does not recognize, so an older app can still open a design saved by a newer one. Fundraisers do not process payments; they open a prefilled Venmo or Cash App link and the host marks guests as paid.

## Guest web page

`web/` is the page guests see when they open an invite link without the app: poster, RSVP, fundraiser, guest list and chat. It is static HTML and JS plus one Vercel function, with no build step and no npm dependencies.

```sh
node --test web/test                       # payment links and the preview function
python3 -m http.server 4173 -d web         # then open http://localhost:4173/page.html?demo=1
```

With `web/config.js` left blank (or with `?demo=1`) the page shows a built-in demo invite. To go live, create a Vercel project with root directory `web`, then set `SUPABASE_URL` and `SUPABASE_ANON_KEY` in its environment or paste them into `web/config.js`. Both values are public (Supabase Project Settings > API).

`/i/:id` is rewritten to `web/api/invite.js`, which fetches the invite with the `get_invite` RPC and returns `page.html` with Open Graph tags, so an iMessage link preview shows the poster and date. The browser talks to Supabase only through RPCs (`respond`, `invite_public_summary`, `invite_messages`, `post_message`), since anon has no table access. Guests are anonymous: a random token in `localStorage` lets them change their answer and post to the chat. There is no realtime for anon, so the page polls every 4 seconds while visible.

Before release: replace `TEAMID` in `web/.well-known/apple-app-site-association` with the Apple developer team id, `app-id=0` in `web/api/invite.js` with the App Store id, and the contact address in `web/privacy.html`. Link previews show times in US Eastern because invites store no time zone.
