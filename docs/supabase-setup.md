# Supabase setup

One-time setup for the backend. It takes about 15 minutes.

1. Go to supabase.com, sign in, and click New project. Pick a name, a database password (save it somewhere), and the region closest to you. Wait for the project to finish creating.
2. Open SQL Editor in the left sidebar, click New query, paste the whole of `supabase/migrations/0001_init.sql`, and click Run. It should say "Success. No rows returned".
3. To check the access rules, open a new query, paste `supabase/tests/rls.sql`, and run it. No error means every check passed. It undoes its own test data.
4. Open Authentication, then Sign In / Providers (older dashboards: Providers under Configuration). Under Email, switch off "Confirm email" for v1. If you leave it on, sign-up creates no session: the new account cannot use the app until its owner taps the link in the confirmation email.
5. Enable the Apple provider on the same page. In the "Client IDs" field enter the app's bundle ID, `com.davat.app`. Native Sign in with Apple needs no secret key. In the Apple Developer portal, the App ID for `com.davat.app` must have the Sign in with Apple capability turned on.
6. Open Project Settings, then API. Copy the Project URL and the `anon` `public` key. Do not copy the `service_role` key; it must never go in the app or the web page.
7. In `project.yml`, paste them into the `SupabaseURL` and `SupabaseAnonKey` entries under the `info` properties of both the Davat and DavatMessages targets, then run `xcodegen generate`. This writes them into `Davat/Info.plist` and `DavatMessages/Info.plist`, so the iMessage extension talks to the same project.
8. In `web/config.js`, paste the same two values into `supabaseURL` and `supabaseAnonKey`.
9. Build and run the app. Sign up with an email, create an invite, and check that a row appears under Table Editor, then `invites`.

Notes:

- Poster images live in the public `posters` storage bucket. The app has to upload under a folder named after the user's id, such as `<user id>/<invite id>.png`. Storage rejects any other folder, and `invites.poster_path` must be exactly `<uuid>/<uuid>.png` in lowercase.
- Deleting an account removes the user's profile and invites, and with the invites every guest response and chat message on them. It also removes that user's own responses and messages on other hosts' invites. Supabase does not allow deleting storage objects from SQL, so the app first lists and removes every file under the user's folder in `posters`, then calls `delete_me`. That cleanup is best effort: if it fails (no network, say), the account is still deleted and the leftover files can be removed from Storage in the dashboard.
- Hosts can delete chat messages and guest responses on their own invites. Guests report an invite through the form on the web page; reports land in the `reports` table.
