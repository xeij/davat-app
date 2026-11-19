// Port of DavatKit/Sources/DavatKit/PaymentLinks.swift. Keep the two in step.

// Keeps only what a handle can hold, [A-Za-z0-9_-]: drops "@", "$" and anything that could change the link.
const clean = (s) => (s ?? "").replace(/[^A-Za-z0-9_-]/g, "");

// "20.50" for 2050
const decimal = (cents) => `${Math.trunc(cents / 100)}.${String(cents % 100).padStart(2, "0")}`;

// Swift's urlQueryAllowed minus "&+=#": encodeURIComponent plus these left alone.
const encodeNote = (s) => {
  try {
    return encodeURIComponent(s).replace(/%(24|2C|2F|3A|3B|3F|40)/g, (m) => decodeURIComponent(m));
  } catch {
    return "";
  }
};

export function venmo(handle, cents, note) {
  const h = clean(handle);
  if (!h) return null;
  return `https://venmo.com/u/${h}?txn=pay&amount=${decimal(cents)}&note=${encodeNote(note)}`;
}

export function cashApp(tag, cents) {
  const t = clean(tag);
  if (!t) return null;
  return `https://cash.app/$${t}/${decimal(cents)}`;
}

export const formatCents = (cents) => (cents % 100 === 0 ? `$${cents / 100}` : `$${decimal(cents)}`);
