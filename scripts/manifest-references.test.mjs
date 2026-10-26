import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { mkdtempSync, readFileSync, rmSync, symlinkSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import test from "node:test";
import { fileURLToPath } from "node:url";

import { manifestReferences } from "./manifest-references.mjs";

const manifestPath = fileURLToPath(new URL("../extension/manifest.json", import.meta.url));
const shippedReferences = [
  "icons/icon-128.png",
  "icons/icon-16.png",
  "icons/icon-32.png",
  "icons/icon-48.png",
  "popup/popup.html",
  "src/service-worker.js",
];

test("the shipped manifest references its service worker, popup, and icons", () => {
  const manifest = JSON.parse(readFileSync(manifestPath));

  assert.deepEqual(manifestReferences(manifest), shippedReferences);
});

test("the command line prints one reference per line for packaging", () => {
  const output = execFileSync(process.execPath, [
    fileURLToPath(new URL("./manifest-references.mjs", import.meta.url)),
    manifestPath,
  ]);

  assert.deepEqual(output.toString().trim().split("\n"), shippedReferences);
});

test("the command line also runs when reached through a symlink", () => {
  const directory = mkdtempSync(join(tmpdir(), "manifest-references-"));
  try {
    const link = join(directory, "scripts");
    symlinkSync(fileURLToPath(new URL(".", import.meta.url)), link);
    const output = execFileSync(process.execPath, [
      join(link, "manifest-references.mjs"),
      manifestPath,
    ]);

    assert.deepEqual(output.toString().trim().split("\n"), shippedReferences);
  } finally {
    rmSync(directory, { recursive: true, force: true });
  }
});

test("importing the module never runs or breaks the command line", () => {
  const moduleURL = new URL("./manifest-references.mjs", import.meta.url).href;
  // `node -` sets argv[1] to "-", which is not a file.
  const output = execFileSync(process.execPath, ["-"], {
    input: `const { manifestReferences } = await import(${JSON.stringify(moduleURL)});
console.log(typeof manifestReferences);`,
  });

  assert.equal(output.toString().trim(), "function");
});

test("a single default icon path is a reference", () => {
  assert.deepEqual(manifestReferences({ action: { default_icon: "icons/icon.png" } }), [
    "icons/icon.png",
  ]);
});

test("absent optional entries contribute no references", () => {
  assert.deepEqual(manifestReferences({ manifest_version: 3 }), []);
});

test("every page, script, and rule file entry point is a reference", () => {
  assert.deepEqual(
    manifestReferences({
      options_page: "options.html",
      options_ui: { page: "options/ui.html" },
      side_panel: { default_path: "panel.html" },
      devtools_page: "devtools.html",
      chrome_url_overrides: { newtab: "newtab.html" },
      sandbox: { pages: ["sandbox.html"] },
      declarative_net_request: { rule_resources: [{ id: "r", path: "rules.json" }] },
      storage: { managed_schema: "schema.json" },
      content_scripts: [{ js: ["content/a.js"], css: ["content/a.css"] }],
    }),
    [
      "content/a.css",
      "content/a.js",
      "devtools.html",
      "newtab.html",
      "options.html",
      "options/ui.html",
      "panel.html",
      "rules.json",
      "sandbox.html",
      "schema.json",
    ],
  );
});

test("manifest keys that packaging cannot model are rejected", () => {
  for (const [key, manifest] of [
    ["default_locale", { default_locale: "en" }],
    ["web_accessible_resources", { web_accessible_resources: [] }],
    ["background.scripts", { background: { scripts: ["bg.js"] } }],
    ["background.page", { background: { page: "bg.html" } }],
  ]) {
    assert.throws(() => manifestReferences(manifest), new RegExp(`${key} is not supported`), key);
  }
});

test("a container of the wrong type names its manifest key", () => {
  for (const [key, manifest] of [
    ["background", { background: null }],
    ["chrome_url_overrides", { chrome_url_overrides: "newtab.html" }],
    ["sandbox.pages", { sandbox: { pages: "sandbox.html" } }],
    ["content_scripts\\[0\\]", { content_scripts: [null] }],
    ["content_scripts\\[0\\]\\.js", { content_scripts: [{ js: "a.js" }] }],
  ]) {
    assert.throws(() => manifestReferences(manifest), new RegExp(`^Error: ${key} must be`), key);
  }
});

test("equivalent spellings of a path are normalized", () => {
  assert.deepEqual(
    manifestReferences({ background: { service_worker: "./src//service-worker.js" } }),
    ["src/service-worker.js"],
  );
});

test("a reference that does not name a file inside the extension is rejected", () => {
  for (const path of ["/src/service-worker.js", "../LICENSE", "src/../../LICENSE", "", "src/..", "src/"]) {
    assert.throws(
      () => manifestReferences({ background: { service_worker: path } }),
      /background\.service_worker must name a file inside the extension/,
      JSON.stringify(path),
    );
  }
});

test("a reference that is not a string names its manifest key", () => {
  assert.throws(
    () => manifestReferences({ background: { service_worker: null } }),
    /background\.service_worker must be a path string, not null/,
  );
});
