// GET /i/:id (rewritten to /api/invite?id=:id). Serves page.html with link-preview tags for the invite.
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

const root = path.join(__dirname, "..");
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

const esc = (s) =>
  String(s ?? "").replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[c]);

// Env wins; otherwise the same values the browser reads from config.js.
function config() {
  const sandbox = { window: {} };
  try {
    vm.runInNewContext(fs.readFileSync(path.join(root, "config.js"), "utf8"), sandbox);
  } catch {}
  const c = sandbox.window.DAVAT_CONFIG || {};
  return { url: process.env.SUPABASE_URL || c.supabaseURL || "", key: process.env.SUPABASE_ANON_KEY || c.supabaseAnonKey || "" };
}

// ponytail: invites carry no time zone, so previews use US Eastern. Store the host's zone on the invite to fix.
const dateLine = (iso) =>
  new Intl.DateTimeFormat("en-US", {
    weekday: "short", month: "short", day: "numeric", hour: "numeric", minute: "2-digit", timeZone: "America/New_York",
  }).format(new Date(iso));

const GONE = `<!doctype html><html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1"><title>davat</title>
<link rel="stylesheet" href="/style.css"></head>
<body><main class="gone"><h1>this invite isn't here anymore</h1><p>the host may have deleted it. ask them for a fresh link.</p></main></body></html>`;

async function fetchInvite(url, key, id) {
  const r = await fetch(`${url}/rest/v1/rpc/get_invite`, {
    method: "POST",
    headers: { apikey: key, Authorization: `Bearer ${key}`, "Content-Type": "application/json" },
    body: JSON.stringify({ invite_id: id }),
  });
  if (!r.ok) throw new Error(`get_invite ${r.status}`);
  return (await r.json())[0] || null;
}

module.exports = async function handler(req, res) {
  const id = new URL(req.url, "http://x").searchParams.get("id") || "";
  const { url, key } = config();
  const send = (status, html) => {
    res.statusCode = status;
    res.setHeader("Content-Type", "text/html; charset=utf-8");
    res.setHeader("Cache-Control", "public, max-age=0, s-maxage=60");
    res.end(html);
  };

  const page = fs.readFileSync(path.join(root, "page.html"), "utf8");
  if (!url || !key) return send(200, page); // not configured yet: the page shows its demo
  if (!UUID.test(id)) return send(404, GONE);

  let invite;
  try {
    invite = await fetchInvite(url, key, id);
  } catch {
    return send(200, page); // Supabase hiccup: skip the preview tags, the page loads the invite itself
  }
  if (!invite) return send(404, GONE);

  const link = `https://${req.headers.host}/i/${id.toLowerCase()}`;
  const tags = [
    `<title>${esc(invite.title || "davat")}</title>`,
    `<meta property="og:title" content="${esc(invite.title || "you're invited")}">`,
    `<meta property="og:description" content="${esc(invite.starts_at ? dateLine(invite.starts_at) : "you're invited")}">`,
    invite.poster_path &&
      `<meta property="og:image" content="${esc(`${url}/storage/v1/object/public/posters/${encodeURI(invite.poster_path)}`)}">`,
    `<meta name="twitter:card" content="summary_large_image">`,
    `<!-- TODO: replace app-id=0 with the App Store id once Davat is listed -->`,
    `<meta name="apple-itunes-app" content="app-id=0, app-argument=${esc(link)}">`,
    // Env-configured deploys still hand the browser its keys, even with config.js left blank.
    `<script>window.DAVAT_CONFIG=${JSON.stringify({ supabaseURL: url, supabaseAnonKey: key }).replace(/</g, "\\u003c")}</script>`,
  ].filter(Boolean);
  send(200, page.replace("<title>davat</title>", () => tags.join("\n")));
};
