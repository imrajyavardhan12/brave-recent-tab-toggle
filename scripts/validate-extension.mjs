import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { createHash } from "node:crypto";
import { existsSync, readFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const root = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const extension = resolve(root, "extension");
const manifest = JSON.parse(readFileSync(resolve(extension, "manifest.json")));

assert.equal(manifest.manifest_version, 3);
assert.equal(manifest.minimum_chrome_version, "121");
assert.deepEqual(manifest.permissions, ["nativeMessaging"]);
assert.equal(manifest.host_permissions, undefined);

const publicKey = Buffer.from(manifest.key, "base64");
const digest = createHash("sha256").update(publicKey).digest().subarray(0, 16);
const extensionID = [...digest]
  .flatMap((byte) => [byte >> 4, byte & 15])
  .map((nibble) => String.fromCharCode("a".charCodeAt(0) + nibble))
  .join("");
assert.equal(extensionID, "edcgmlcjhdpdanpfhgcnbkeppbaijbmd");

const requiredFiles = [
  manifest.background.service_worker,
  manifest.action.default_popup,
  ...Object.values(manifest.icons),
  ...Object.values(manifest.action.default_icon),
];
for (const path of requiredFiles) {
  assert.ok(existsSync(resolve(extension, path)), `missing extension file: ${path}`);
}

for (const path of [
  "src/background.js",
  "src/service-worker.js",
  "src/tab-toggle.js",
  "popup/popup.js",
  "popup/popup-view.js",
]) {
  execFileSync(process.execPath, ["--check", resolve(extension, path)]);
}

console.log(`✓ Manifest V3 extension is valid (${extensionID})`);
