import { readFileSync, realpathSync } from "node:fs";
import { posix } from "node:path";
import { fileURLToPath } from "node:url";

// Keys that name files in ways this module does not model: a locale directory, globs, or
// Manifest V2 background pages. Rejecting them is safer than packaging without the files.
const UNSUPPORTED_KEYS = [
  ["default_locale", (manifest) => manifest.default_locale],
  ["web_accessible_resources", (manifest) => manifest.web_accessible_resources],
  ["background.scripts", (manifest) => manifest.background?.scripts],
  ["background.page", (manifest) => manifest.background?.page],
];

// The single definition of the extension files a manifest names. The validator checks they
// exist, and packaging (through the command line below) checks they ship.
export function manifestReferences(manifest) {
  for (const [key, value] of UNSUPPORTED_KEYS) {
    if (value(manifest) !== undefined) {
      throw new Error(`manifest key ${key} is not supported by packaging yet`);
    }
  }
  const action = object("action", manifest.action);
  const background = object("background", manifest.background);
  const references = [
    ["background.service_worker", background.service_worker],
    ["action.default_popup", action.default_popup],
    ...iconReferences("action.default_icon", action.default_icon),
    ...iconReferences("icons", manifest.icons),
    ["options_page", manifest.options_page],
    ["options_ui.page", object("options_ui", manifest.options_ui).page],
    ["side_panel.default_path", object("side_panel", manifest.side_panel).default_path],
    ["devtools_page", manifest.devtools_page],
    ["storage.managed_schema", object("storage", manifest.storage).managed_schema],
    ...entries("chrome_url_overrides", manifest.chrome_url_overrides),
    ...list("sandbox.pages", object("sandbox", manifest.sandbox).pages).map((path, index) => [
      `sandbox.pages[${index}]`,
      path,
    ]),
    ...list(
      "declarative_net_request.rule_resources",
      object("declarative_net_request", manifest.declarative_net_request).rule_resources,
    ).map((resource, index) => {
      const key = `declarative_net_request.rule_resources[${index}]`;
      return [`${key}.path`, object(key, resource).path];
    }),
    ...list("content_scripts", manifest.content_scripts).flatMap((script, index) => {
      const key = `content_scripts[${index}]`;
      const { js, css } = object(key, script);
      return [
        ...list(`${key}.js`, js).map((path, file) => [`${key}.js[${file}]`, path]),
        ...list(`${key}.css`, css).map((path, file) => [`${key}.css[${file}]`, path]),
      ];
    }),
  ].filter(([, path]) => path !== undefined);
  return [...new Set(references.map(([key, path]) => normalize(key, path)))].sort();
}

function object(key, value) {
  if (value === undefined) return {};
  if (typeof value !== "object" || value === null || Array.isArray(value)) {
    throw new Error(`${key} must be an object, not ${JSON.stringify(value)}`);
  }
  return value;
}

function list(key, value) {
  if (value === undefined) return [];
  if (!Array.isArray(value)) {
    throw new Error(`${key} must be an array, not ${JSON.stringify(value)}`);
  }
  return value;
}

function entries(key, value) {
  return Object.entries(object(key, value)).map(([name, path]) => [`${key}.${name}`, path]);
}

// Manifest V3 accepts either one icon path or a map from size to path.
function iconReferences(key, icons) {
  return typeof icons === "string" ? [[key, icons]] : entries(key, icons);
}

function normalize(key, path) {
  if (typeof path !== "string") {
    throw new Error(`${key} must be a path string, not ${JSON.stringify(path)}`);
  }
  const normalized = posix.normalize(path);
  if (
    normalized === "." ||
    normalized.endsWith("/") ||
    posix.isAbsolute(normalized) ||
    normalized.split("/")[0] === ".."
  ) {
    throw new Error(`${key} must name a file inside the extension: ${JSON.stringify(path)}`);
  }
  return normalized;
}

// Compare real paths: argv keeps symlinks, but import.meta.url has them resolved. argv[1]
// may also be absent or not a file at all (for example "-" under `node -`).
function isMainModule() {
  try {
    return realpathSync(process.argv[1]) === fileURLToPath(import.meta.url);
  } catch {
    return false;
  }
}

// `node manifest-references.mjs <manifest.json>` prints one reference per line for packaging.
if (isMainModule()) {
  try {
    const manifest = JSON.parse(readFileSync(process.argv[2]));
    console.log(manifestReferences(manifest).join("\n"));
  } catch (error) {
    console.error(error.message);
    process.exitCode = 1;
  }
}
