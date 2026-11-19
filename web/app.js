import { venmo, cashApp, formatCents } from "/links.js";

const cfg = window.DAVAT_CONFIG || {};
const params = new URLSearchParams(location.search);
const demo = params.has("demo") || !cfg.supabaseURL || !cfg.supabaseAnonKey;
const inviteId = demo ? "demo" : location.pathname.match(/\/i\/([^/]+)/)?.[1] || params.get("id") || "";
const reducedMotion = matchMedia("(prefers-reduced-motion: reduce)").matches;
const $ = (s) => document.querySelector(s);

// --- storage: davat:<inviteId> holds {token, name, rsvp, paid}

const load = (k) => {
  try { return JSON.parse(localStorage.getItem(k)); } catch { return null; }
};
const save = (k, v) => {
  try { localStorage.setItem(k, JSON.stringify(v)); } catch {}
};
const KEY = `davat:${inviteId}`;
const me = { token: crypto.randomUUID(), name: "", rsvp: null, paid: false, ...load(KEY) };

// --- backend: the anon API is RPC only

async function rest(pathname, body, extra = {}) {
  const r = await fetch(`${cfg.supabaseURL}/rest/v1/${pathname}`, {
    method: "POST",
    headers: { apikey: cfg.supabaseAnonKey, Authorization: `Bearer ${cfg.supabaseAnonKey}`, "Content-Type": "application/json", ...extra },
    body: JSON.stringify(body),
  });
  if (!r.ok) throw new Error(`${pathname} ${r.status}`);
  return r.status === 204 ? null : r.json();
}
const rpc = (fn, args) => (demo ? demoRpc(fn, args) : rest(`rpc/${fn}`, args));

// --- demo: an in-memory invite so the page can be previewed without Supabase

const demoState = {
  invite: {
    id: "demo", title: "leila's 30th", starts_at: "2026-12-06T01:00:00Z", time_zone: "America/New_York", location: "the roof at 214 grand st",
    details: "dinner at 8, then dancing.\nbring a sweater, it gets windy up there.",
    design: { effect: "confetti", envelope: true }, poster_path: null, price_cents: 2000, host_pays: true,
  },
  responses: [
    { token: "maya", name: "maya", rsvp: "going", paid: true },
    { token: "sam", name: "sam", rsvp: "going", paid: false },
    { token: "jordan", name: "jordan", rsvp: "going", paid: false },
    { token: "priya", name: "priya", rsvp: "maybe", paid: false },
  ],
  messages: [
    { id: "1", name: "leila", body: "so happy you can all make it" },
    { id: "2", name: "maya", body: "what's the dress code?" },
    { id: "3", name: "leila", body: "warm and sparkly" },
  ],
};

function demoRpc(fn, a) {
  const s = demoState;
  if (fn === "get_invite") return [s.invite];
  if (fn === "invite_messages") return s.messages;
  if (fn === "post_message") return s.messages.push({ id: String(s.messages.length + 1), name: a.name, body: a.body });
  if (fn === "respond") {
    const r = s.responses.find((x) => x.token === a.guest_token) || s.responses[s.responses.push({ token: a.guest_token, paid: false }) - 1];
    Object.assign(r, { name: a.name, rsvp: a.rsvp, paid: a.paid ?? r.paid });
    return r;
  }
  // invite_public_summary, same math as the SQL
  const going = s.responses.filter((r) => r.rsvp === "going");
  const host = s.invite.host_pays ? 1 : 0;
  return [{
    guests: s.responses.map(({ name, rsvp }) => ({ name, rsvp })).sort((x, y) => x.name.localeCompare(y.name)),
    going_count: going.length,
    goal_cents: s.invite.price_cents * (going.length + host),
    raised_cents: s.invite.price_cents * (going.filter((r) => r.paid).length + host),
    host_venmo: "leila", host_cashtag: "leila",
  }];
}

// --- ui

let invite;

const toast = (text) => {
  const t = $("#toast");
  t.textContent = text;
  t.classList.add("show");
  clearTimeout(toast.timer);
  toast.timer = setTimeout(() => t.classList.remove("show"), 2600);
};

function askName() {
  const d = $("#name-dialog");
  const input = $("#name-input");
  input.value = me.name;
  d.returnValue = "";
  d.showModal();
  return new Promise((resolve) =>
    d.addEventListener("close", () => {
      const name = [...input.value.trim()].slice(0, 60).join(""); // 60 code points, as Postgres counts
      if (d.returnValue !== "ok" || !name) return resolve(false);
      me.name = name;
      save(KEY, me);
      paint();
      resolve(true);
    }, { once: true }));
}
$("#name-cancel").onclick = () => $("#name-dialog").close();

function paint() {
  for (const b of document.querySelectorAll("[data-rsvp]")) b.setAttribute("aria-pressed", String(b.dataset.rsvp === me.rsvp));
  $("#rsvp-note").hidden = !me.name;
  $("#me-name").textContent = me.name;
  $("#paid").disabled = me.paid;
  $("#paid").textContent = me.paid ? "marked as going and paid" : "I paid";
}

// paid: true only from the "I paid" button; null keeps whatever the host or an earlier tap set.
async function answer(rsvp, paid = null) {
  if (!me.name && !(await askName())) return;
  const before = { ...me };
  me.rsvp = rsvp;
  if (paid) me.paid = true;
  paint();
  try {
    await rpc("respond", { invite_id: inviteId, guest_token: me.token, name: me.name, rsvp, paid });
    save(KEY, me);
    poll();
  } catch {
    Object.assign(me, before);
    paint();
    toast("that didn't go through. try again?");
  }
}

for (const b of document.querySelectorAll("[data-rsvp]")) b.onclick = () => answer(b.dataset.rsvp);
$("#paid").onclick = () => answer("going", true); // paying counts only when going
$("#rename").onclick = async () => {
  if ((await askName()) && me.rsvp) answer(me.rsvp);
};

const RSVP_LABEL = { going: "going", maybe: "maybe", cant: "can't" };

function renderSummary(s) {
  if (!s) return;
  $("#guests-title").textContent = s.going_count ? `${s.going_count} going` : "who's coming";
  $("#guests").replaceChildren(...s.guests.map((g) => {
    const li = document.createElement("li");
    const name = document.createElement("span");
    const pill = document.createElement("span");
    name.textContent = g.name;
    pill.textContent = RSVP_LABEL[g.rsvp];
    pill.className = `pill ${g.rsvp}`;
    li.append(name, pill);
    return li;
  }));
  if (invite.price_cents == null) return;
  const goal = Number(s.goal_cents), raised = Number(s.raised_cents);
  $("#raised").textContent = `${formatCents(raised)} of ${formatCents(goal)} in`;
  $("#bar").style.width = `${goal ? Math.min(100, (raised / goal) * 100) : 0}%`;
  const links = [
    ["venmo", venmo(s.host_venmo || "", invite.price_cents, invite.title)],
    ["cash app", cashApp(s.host_cashtag || "", invite.price_cents)],
  ].filter(([, href]) => href);
  $("#pay").replaceChildren(...links.map(([label, href]) => {
    const a = document.createElement("a");
    a.className = "glass accent";
    a.href = href;
    a.target = "_blank";
    a.rel = "noopener";
    a.textContent = label;
    return a;
  }));
}

let lastMessage = "";
function renderMessages(msgs) {
  const key = `${msgs.length}:${msgs.at(-1)?.id}`;
  if (key === lastMessage) return;
  lastMessage = key;
  const list = $("#messages");
  list.replaceChildren(...msgs.map((m) => {
    const li = document.createElement("li");
    const who = document.createElement("b");
    who.textContent = m.name;
    li.append(who, m.body);
    // ponytail: "mine" is matched by name, so two guests with one name both look like you. Track posted ids if it matters.
    li.className = `bubble${m.name === me.name ? " mine" : ""}`;
    return li;
  }));
  list.scrollTop = list.scrollHeight;
}

async function poll() {
  try {
    const [[summary], msgs] = await Promise.all([
      rpc("invite_public_summary", { invite_id: inviteId }),
      rpc("invite_messages", { invite_id: inviteId }),
    ]);
    renderSummary(summary);
    renderMessages(msgs);
  } catch {}
}

// Every 4s while the tab is visible. There is no realtime for anon.
let timer;
function schedule() {
  clearInterval(timer);
  if (document.hidden) return;
  poll();
  timer = setInterval(poll, 4000);
}

$("#chat-form").onsubmit = async (e) => {
  e.preventDefault();
  const input = $("#chat-input");
  const body = [...input.value.trim()].slice(0, 1000).join("");
  if (!body || (!me.name && !(await askName()))) return;
  input.value = "";
  try {
    await rpc("post_message", { invite_id: inviteId, name: me.name, guest_token: me.token, body });
    poll();
  } catch {
    input.value = body;
    toast("couldn't send that. try again?");
  }
};

$("#report-form").onsubmit = async (e) => {
  e.preventDefault();
  try {
    await rest("reports", { invite_id: inviteId, reason: $("#report-reason").value.trim() }, { Prefer: "return=minimal" });
    $("#report").replaceChildren(Object.assign(document.createElement("p"), { textContent: "thanks, we'll take a look." }));
  } catch {
    toast("couldn't send the report. try again?");
  }
};

// --- effects: canvas particles over the poster, same names as Effect in Design.swift

function startEffect(kind) {
  if (!["confetti", "snow", "sparkle", "hearts", "bubbles", "petals"].includes(kind) || reducedMotion) return;
  const canvas = $("#fx");
  const ctx = canvas.getContext("2d");
  let w, h;
  const size = () => {
    const dpr = devicePixelRatio || 1;
    w = canvas.clientWidth;
    h = canvas.clientHeight;
    canvas.width = w * dpr;
    canvas.height = h * dpr;
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
  };
  size();
  addEventListener("resize", size);

  const rand = (a, b) => a + Math.random() * (b - a);
  const colors = { confetti: ["#D9922E", "#F2C14E", "#E8576B", "#5BC0BE", "#FFFFFF"], hearts: ["#E8576B", "#FF8FA3", "#D9922E"],
    bubbles: ["rgba(255,255,255,.8)", "rgba(255,255,255,.5)"], petals: ["#FFC7D9", "#FAA6BF", "#CCB3F2"] }[kind];
  const spawn = (p, anywhere) => Object.assign(p, {
    x: rand(0, w),
    y: anywhere || kind === "sparkle" ? rand(0, h) : kind === "hearts" || kind === "bubbles" ? h + 20 : -20,
    vy: { confetti: rand(1.2, 2.8), snow: rand(0.4, 1.2), sparkle: 0, hearts: -rand(0.5, 1.2), bubbles: -rand(0.5, 1.2), petals: rand(0.4, 0.9) }[kind],
    r: { confetti: rand(4, 7), snow: rand(1.5, 4), sparkle: rand(3, 7), hearts: rand(10, 18), bubbles: rand(4, 13), petals: rand(4, 7) }[kind],
    a: rand(0, 6.28), t: rand(0, 6.28), sway: rand(0.02, 0.05),
    c: colors ? colors[Math.floor(Math.random() * colors.length)] : "#fff",
  });
  const n = { confetti: 70, snow: 80, sparkle: 36, hearts: 22, bubbles: 32, petals: 40 }[kind];
  const ps = Array.from({ length: n }, () => spawn({}, true));

  const heart = (s) => {
    ctx.beginPath();
    ctx.moveTo(0, s / 4);
    ctx.bezierCurveTo(0, 0, -s / 2, 0, -s / 2, s / 4);
    ctx.bezierCurveTo(-s / 2, s / 2, 0, s * 0.75, 0, s);
    ctx.bezierCurveTo(0, s * 0.75, s / 2, s / 2, s / 2, s / 4);
    ctx.bezierCurveTo(s / 2, 0, 0, 0, 0, s / 4);
    ctx.fill();
  };
  const star = (r) => {
    ctx.beginPath();
    for (let i = 0; i < 8; i++) {
      const len = i % 2 ? r / 4 : r;
      ctx.lineTo(Math.cos((i * Math.PI) / 4) * len, Math.sin((i * Math.PI) / 4) * len);
    }
    ctx.fill();
  };

  (function frame() {
    ctx.clearRect(0, 0, w, h);
    for (const p of ps) {
      p.t += p.sway;
      p.y += p.vy;
      p.x += Math.sin(p.t) * (kind === "confetti" || kind === "petals" ? 0.8 : 0.4);
      p.a += 0.05;
      if (p.y > h + 30 || p.y < -30) spawn(p, false);
      ctx.save();
      ctx.translate(p.x, p.y);
      ctx.fillStyle = p.c;
      if (kind === "confetti") {
        ctx.rotate(p.a);
        ctx.scale(1, Math.cos(p.t * 3));
        ctx.fillRect(-p.r, -p.r / 2, p.r * 2, p.r);
      } else if (kind === "snow") {
        ctx.globalAlpha = 0.85;
        ctx.beginPath();
        ctx.arc(0, 0, p.r, 0, 6.28);
        ctx.fill();
      } else if (kind === "sparkle") {
        ctx.globalAlpha = Math.max(0, Math.sin(p.t * 2));
        if (ctx.globalAlpha === 0 && Math.random() < 0.02) spawn(p, true);
        star(p.r);
      } else if (kind === "bubbles") {
        ctx.strokeStyle = p.c;
        ctx.lineWidth = Math.max(1, p.r * 0.24);
        ctx.beginPath();
        ctx.arc(0, 0, p.r, 0, 6.28);
        ctx.stroke();
      } else if (kind === "petals") {
        ctx.rotate(p.a);
        ctx.scale(Math.cos(p.t * 1.7), 1);
        ctx.beginPath();
        ctx.ellipse(0, 0, p.r, p.r * 0.6, 0, 0, 6.28);
        ctx.fill();
      } else {
        ctx.globalAlpha = 0.9;
        heart(p.r);
      }
      ctx.restore();
    }
    requestAnimationFrame(frame);
  })();
}

// --- envelope: shown once per invite

function envelope(title) {
  const seenKey = `davat:${inviteId}:opened`;
  if (reducedMotion || load(seenKey)) return;
  const el = $("#envelope");
  $("#env-card").textContent = title;
  el.hidden = false;
  let done = false;
  const open = () => {
    if (done) return;
    done = true;
    save(seenKey, true);
    el.classList.add("open");
    setTimeout(() => el.remove(), 1800);
  };
  el.onclick = open;
  setTimeout(open, 2500);
}

// --- start

// In the host's zone; invites saved before zones existed show the date only, in UTC.
function when(iso, zone) {
  const opts = { weekday: "long", month: "long", day: "numeric" };
  try {
    if (zone) return new Date(iso).toLocaleString(undefined, { ...opts, hour: "numeric", minute: "2-digit", timeZone: zone }).toLowerCase();
  } catch {} // unknown zone
  return new Date(iso).toLocaleDateString(undefined, { ...opts, timeZone: "UTC" }).toLowerCase();
}

// A republish overwrites the same file, which storage caches for an hour, so ask for this version.
function posterURL(inv) {
  const v = Date.parse(inv.updated_at);
  return `${cfg.supabaseURL}/storage/v1/object/public/posters/${encodeURI(inv.poster_path)}${Number.isFinite(v) ? `?v=${Math.floor(v / 1000)}` : ""}`;
}

function fail(text, sub) {
  const main = document.createElement("main");
  main.className = "gone";
  const h = document.createElement("h1");
  const p = document.createElement("p");
  h.textContent = text;
  p.textContent = sub;
  main.append(h, p);
  $("#app").replaceWith(main);
}

async function start() {
  if (!demo && !/^[0-9a-f-]{36}$/i.test(inviteId)) return fail("this invite isn't here anymore", "the link looks off. ask the host to send it again.");
  try {
    [invite] = await rpc("get_invite", { invite_id: inviteId });
  } catch {
    return fail("couldn't load this invite", "check your connection and refresh.");
  }
  if (!invite) return fail("this invite isn't here anymore", "the host may have deleted it. ask them for a fresh link.");

  document.title = invite.title || "davat";
  const poster = invite.poster_path ? posterURL(invite) : demo ? "/demo-poster.svg" : "";
  if (poster) {
    $("#poster").src = poster;
    $("#backdrop").style.backgroundImage = `url("${poster}")`;
  }
  $("#title").textContent = invite.title;
  if (invite.starts_at) $("#when").textContent = when(invite.starts_at, invite.time_zone);
  $("#where").textContent = invite.location;
  $("#details").textContent = invite.details;
  if (invite.price_cents != null) {
    $("#fund").hidden = false;
    $("#share").textContent = formatCents(invite.price_cents);
  }
  $("#report").hidden = demo;
  if (location.hash === "#report" && !demo) { // the iMessage card's report link
    $("#report").open = true;
    $("#report").scrollIntoView();
  }

  paint();
  if (invite.design?.envelope) envelope(invite.title);
  startEffect((demo && params.get("effect")) || invite.design?.effect);
  schedule();
  document.addEventListener("visibilitychange", schedule);
}

start();
