import { test } from "node:test";
import assert from "node:assert/strict";
import { createRequire } from "node:module";

const handler = createRequire(import.meta.url)("../api/invite.js");
const ID = "0b6a3c6e-6a4f-4d2b-9a7e-1f2e3d4c5b6a";

async function call(id, rows) {
  process.env.SUPABASE_URL = "https://x.supabase.co";
  process.env.SUPABASE_ANON_KEY = "anon";
  const seen = [];
  globalThis.fetch = async (url, init) => {
    seen.push({ url, init });
    return { ok: true, status: 200, json: async () => rows };
  };
  const res = { headers: {}, setHeader(k, v) { this.headers[k] = v; }, end(body) { this.body = body; } };
  await handler({ url: `/api/invite?id=${id}`, headers: { host: "davat.vercel.app" } }, res);
  return { res, seen };
}

test("injects escaped preview tags", async () => {
  const { res, seen } = await call(ID, [
    { title: `<script>"x" & 'y'</script>`, starts_at: "2026-12-06T01:00:00Z", poster_path: "u/p.png" },
  ]);
  assert.equal(res.statusCode, 200);
  assert.equal(seen[0].url, "https://x.supabase.co/rest/v1/rpc/get_invite");
  assert.equal(seen[0].init.headers.Authorization, "Bearer anon");
  assert.match(res.body, /<meta property="og:title" content="&lt;script&gt;&quot;x&quot; &amp; &#39;y&#39;&lt;\/script&gt;">/);
  assert.ok(!res.body.includes(`<script>"x"`));
  assert.match(res.body, /og:description" content="Sat, Dec 5, 8:00 PM"/);
  assert.match(res.body, /og:image" content="https:\/\/x\.supabase\.co\/storage\/v1\/object\/public\/posters\/u\/p\.png"/);
  assert.match(res.body, /app-argument=https:\/\/davat\.vercel\.app\/i\/0b6a3c6e/);
  assert.match(res.body, /twitter:card" content="summary_large_image"/);
});

test("missing date says you're invited", async () => {
  const { res } = await call(ID, [{ title: "t", starts_at: null, poster_path: null }]);
  assert.match(res.body, /og:description" content="you&#39;re invited"/);
  assert.ok(!res.body.includes("og:image"));
});

test("dollar patterns in the title stay literal", async () => {
  const { res } = await call(ID, [{ title: "$$$ party $& more", starts_at: null, poster_path: null }]);
  assert.ok(res.body.includes(`<title>$$$ party $&amp; more</title>`));
  assert.ok(res.body.includes(`og:title" content="$$$ party $&amp; more"`));
});

test("unknown invite is a friendly 404", async () => {
  const { res } = await call(ID, []);
  assert.equal(res.statusCode, 404);
  assert.match(res.body, /this invite isn't here anymore/);
  assert.equal((await call("nope", [])).res.statusCode, 404);
});
