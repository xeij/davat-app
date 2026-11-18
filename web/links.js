// Port of DavatKit/Sources/DavatKit/PaymentLinks.swift. Keep the two in step.

const strip = (s, prefix) => {
  const t = s.trim();
  return t.startsWith(prefix) ? t.slice(1) : t;
};

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
  const h = strip(handle ?? "", "@");
  if (!h) return null;
  return `https://venmo.com/u/${h}?txn=pay&amount=${decimal(cents)}&note=${encodeNote(note)}`;
}

export function cashApp(tag, cents) {
  const t = strip(tag ?? "", "$");
  if (!t) return null;
  return `https://cash.app/$${t}/${decimal(cents)}`;
}

export const formatCents = (cents) => (cents % 100 === 0 ? `$${cents / 100}` : `$${decimal(cents)}`);
