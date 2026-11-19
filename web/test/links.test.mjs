// Same expected strings as DavatKit/Tests/DavatKitTests/PaymentLinksTests.swift.
import { test } from "node:test";
import assert from "node:assert/strict";
import { venmo, cashApp, formatCents } from "../links.js";

test("venmo link", () => {
  assert.equal(venmo("leila", 2000, "Leila's 30th"), "https://venmo.com/u/leila?txn=pay&amount=20.00&note=Leila's%2030th");
});

test("cash app link", () => {
  assert.equal(cashApp("leila", 2050), "https://cash.app/$leila/20.50");
});

test("handles strip prefixes", () => {
  assert.equal(venmo("@leila", 2000, "Leila's 30th"), venmo("leila", 2000, "Leila's 30th"));
  assert.equal(cashApp("$leila", 2050), cashApp("leila", 2050));
  assert.equal(venmo("", 100, "x"), null);
  assert.equal(venmo("@", 100, "x"), null);
  assert.equal(cashApp("", 100), null);
});

test("handles drop other characters", () => {
  assert.equal(venmo(" @le ila/<x>?", 100, "x"), "https://venmo.com/u/leilax?txn=pay&amount=1.00&note=x");
  assert.equal(cashApp("$le_i-la#1", 100), "https://cash.app/$le_i-la1/1.00");
});

test("note keeps query-safe characters and encodes & + = #", () => {
  assert.equal(venmo("a", 100, "a&b+c=d#e $/:;?@,"), "https://venmo.com/u/a?txn=pay&amount=1.00&note=a%26b%2Bc%3Dd%23e%20$/:;?@,");
});

test("formatCents", () => {
  assert.equal(formatCents(2000), "$20");
  assert.equal(formatCents(2050), "$20.50");
  assert.equal(formatCents(0), "$0");
});
