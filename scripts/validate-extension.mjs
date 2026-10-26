import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { createHash } from "node:crypto";
import { existsSync, readdirSync, readFileSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const root = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const extension = resolve(root, "extension");
const manifest = JSON.parse(readFileSync(resolve(extension, "manifest.json")));
const packageMetadata = JSON.parse(readFileSync(resolve(root, "package.json")));

assert.equal(manifest.manifest_version, 3);
assert.equal(manifest.version, packageMetadata.version);
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

// Walk by hand: readdirSync's recursive option needs Node 20.1, and engines allows 20.0.
function scriptsIn(directory) {
  return readdirSync(resolve(extension, directory), { withFileTypes: true }).flatMap(
    (entry) => {
      const path = join(directory, entry.name);
      if (entry.isDirectory()) return scriptsIn(path);
      return /\.m?js$/.test(entry.name) ? [path] : [];
    },
  );
}

// Check every script in the shipped directories, so a new module cannot skip validation.
for (const path of ["src", "popup"].flatMap(scriptsIn)) {
  execFileSync(process.execPath, ["--check", resolve(extension, path)]);
}

console.log(`✓ Manifest V3 extension is valid (${extensionID})`);
