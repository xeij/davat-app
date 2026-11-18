# Davat design

Davat (Farsi for "invite") is an iPhone app for making custom invites and sending them to friends over iMessage. Friends RSVP, and when the host turns on fundraiser mode, they chip in a fixed share toward a total (for example 4 people at $20 each for an $80 goal).

## Why

The host wants an invite that feels like theirs, whether that's loud and ridiculous or delicate and detailed. Friends should be able to answer in one tap without having to install anything. Splitting the cost of a group thing should happen right inside the invite instead of in a separate Venmo thread.

## Goals

- Account creation and login.
- A freeform invite editor that gives the host as much control as possible.
- Sending through iMessage, both as a live interactive bubble and as a plain link.
- RSVP: Going, Maybe, Can't.
- Fundraiser mode: a per-person share, a goal, and progress for everyone in the thread to see.
- Live chat on each invite for the host and guests.
- Look and feel: current iOS with Liquid Glass translucent buttons, smooth transitions and motion, and thin sharp type set large on the welcome screens and everywhere else.
- Copy that reads like a person wrote it. No em dashes, no AI-sounding phrasing, no decorative formatting.

## Non-goals (v1)

- Moving money inside the app. Payments hand off to Venmo or Cash App, and the guest then marks "I paid". In-app payments (Stripe or Apple Pay) come later. Apple Cash is dropped for v1 because it has no link that pre-fills an amount.
- Cloud AI image generation. AI images come from Apple Image Playground only.
- Android app, iPad layout.
- A photo wall (Partiful has one; a candidate for v2).

## Anti-goals

- An invite that looks different in the app, the bubble and the web page.
- A templated, same-looking feel (Partiful's main criticism) or ads that degrade the invite (Evite).
- Making guests install Davat in order to respond.
- Copy or UI that reads as generated.

## Constraints

- Paid Apple Developer account: yes. Target is the host's phone and TestFlight first, then the App Store. App Store work is part of the plan: a privacy policy, in-app account deletion (required with Sign in with Apple), and reporting an invite.
- Supabase and Vercel accounts don't exist yet. The user creates them when that stage comes up, with step-by-step help. Start on a free `*.vercel.app` address and move to a real domain before wider use. Keep the base URL in one config value.
- iOS 26+ (Liquid Glass via SwiftUI `.glassEffect`, Image Playground). Xcode 27.2 is installed.
- Image Playground needs Apple Intelligence hardware (iPhone 15 Pro or newer). On other devices the AI option is hidden and everything else works.
- Work ships in stages. Each stage goes: `git switch -c <branch>`, `bezan <files> "<message>"` to commit, `git push`, `gh pr create --fill`, `gh pr merge --merge`, `git checkout main`, `git pull`. Repo: `gh repo create davat-app --public --source=. --remote=origin --push`.
- After each stage, a short progress summary is posted to a readable web page (a claude.ai artifact that gets republished), not just the terminal.
- No Claude or Anthropic attribution in commits or PRs.

## Approaches considered

Each invite has to look identical in three places: the app, the iMessage bubble and the web page.

- **A. Native editor plus a published snapshot (chosen).** The SwiftUI editor saves invites as layer JSON so they stay editable. On publish, it renders a full-resolution PNG with `ImageRenderer`. The bubble and the web page show that PNG, and the web page draws the animated effect over it. The result is pixel-identical everywhere, and each font or effect is built once. The tradeoff is that poster text on the web isn't selectable. Event details below the poster stay real text.
- B. Rebuild the design on the web from the layers. The text would be real, but every font, sticker and effect would be built twice and the two versions would drift apart.
- C. A web editor inside a WKWebView. One renderer, but it loses the native feel the user asked for.

The user picked A.

## Decided

**Recipient flow (user chose "both"):**
- If the host has the iMessage extension, the invite goes out as an `MSMessage` live bubble. Otherwise it goes as a link (through the system share sheet or a Messages compose sheet) whose preview shows the poster, title and date through Open Graph tags.
- Guest with Davat: the bubble opens in Messages with RSVP buttons and, in fundraiser mode, "$20 your share · $40 of $80 in" with a Chip in button. The bubble updates for the thread.
- Guest without Davat: the link opens a web page with the same poster, effect and buttons. They enter a name to RSVP. Chip in opens Venmo, Cash App or Apple Cash with the amount filled in, then "I paid".
- The host sees the guest list and payment status live, and can mark people paid by hand, because "I paid" is self-reported.
- The live bubble only stays current for guests who have Davat. Everyone else sees the latest state when they tap through to the web page. (builder's call)
- If the host edits after sending, the same link shows the new version and the PNG is replaced. (builder's call)

**Fundraiser math (user approved):**
- The host sets the per-person price. Goal = price times the number of people who said Going, plus the host if "I'm paying too" is on.
- The invite, the bubble and the web page all show, live, the amount requested, how much has come in, and the progress toward the goal.
- "I paid" counts right away. The host can uncheck anyone who didn't actually pay.
- The host enters their Venmo handle and $cashtag once, on their profile. The Chip in buttons deep-link with the amount filled in: `venmo.com/u/<handle>?txn=pay&amount=<n>` and `cash.app/$<tag>/<n>`.

**Live chat (user asked):** each invite has a chat thread for the host and guests, live through Supabase realtime, on the web page and in the app. Web guests post under the name they gave when they RSVPed.

**Visibility (user approved):** the invite link uses an unguessable ID, so anyone with it can respond. Guests see who's going, the totals and the chat, but not who has paid. Only the host sees who has paid.

**Editor (user: "full control, as much customization as possible"):** a layered canvas, either blank or started from a template.
- Background: a photo, solid color, gradient, pattern, or an Image Playground image.
- Text layers: many fonts, size, color, outline, shadow and curved text.
- Stickers, emoji, photos and shapes, with drag, pinch, rotate and reorder.
- An animated effect layer: confetti, snow, sparkle, hearts.
- An envelope-style reveal when the invite opens.

**Design references (from research):** Apple Invites' full-bleed poster with large title type; Partiful's effects and themes; Paperless Post's attention to detail and reveal moment.

## Builder's calls (stated, user can override)

- Stack: SwiftUI app plus an iMessage extension target, Supabase (auth, Postgres, realtime, storage for PNGs and uploads), and a small static web page on Vercel that reads from Supabase.
- Login: Sign in with Apple plus email.
- Guests on the web are anonymous. They give a name, and the device remembers their response so they can change it.
- Guests who open the bubble and are signed into Davat (login shared with the extension through an App Group) answer as their account. Otherwise they answer with a name, the same way web guests do. The host can merge duplicate guests by hand.
- Template count, font list, sticker set and effect list are up to the builder.
- Build order is the builder's call: suggested shell and auth, then editor, then publish and link, then web page, then iMessage extension, then fundraiser, then chat, then App Store requirements.
