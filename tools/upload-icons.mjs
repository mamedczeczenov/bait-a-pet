/**
 * Upload PNGs from roblox/assets/icons to Roblox Open Cloud and write IconAssetIds.luau
 *
 * Setup:
 *   1. Create Open Cloud API key with "Assets" write (and account auth)
 *   2. Set env:
 *      ROBLOX_API_KEY=...
 *      ROBLOX_CREATOR_ID=...        (your user id OR group id)
 *      ROBLOX_CREATOR_TYPE=User     (or Group)
 *   3. Run from repo:
 *      node roblox/tools/upload-icons.mjs
 *
 * Docs: https://create.roblox.com/docs/cloud/reference/assets
 */

import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ICONS_DIR = path.resolve(__dirname, "../assets/icons");
const OUT_MODULE = path.resolve(
  __dirname,
  "../src/ReplicatedStorage/Modules/IconAssetIds.luau"
);

const API_KEY = (process.env.ROBLOX_API_KEY || "").trim();
const CREATOR_ID = (process.env.ROBLOX_CREATOR_ID || "").trim();
const CREATOR_TYPE = (process.env.ROBLOX_CREATOR_TYPE || "User").trim().toLowerCase();

if (!API_KEY || !CREATOR_ID) {
  console.error(`Missing env.

Set:
  ROBLOX_API_KEY
  ROBLOX_CREATOR_ID
  ROBLOX_CREATOR_TYPE=User|Group

Then: node roblox/tools/upload-icons.mjs
`);
  process.exit(1);
}

// Never print the full key — only length + edges for "did PowerShell eat it?" checks.
console.log(
  `API key loaded: length=${API_KEY.length}, start=${API_KEY.slice(0, 4)}…, end=…${API_KEY.slice(-4)}`
);
if (API_KEY.length < 40) {
  console.error("API key looks too short — PowerShell probably did not set ROBLOX_API_KEY correctly.");
  console.error('Use single quotes: $env:ROBLOX_API_KEY = \'paste_key_here\'');
  process.exit(1);
}

const SKIP = new Set(["_ref_index.png", "_ref_coins.png"]);

function sleep(ms) {
  return new Promise((r) => setTimeout(r, ms));
}

function buildCreator() {
  // Open Cloud expects userId OR groupId — not creatorType/creatorId.
  if (CREATOR_TYPE === "group") {
    return { groupId: String(CREATOR_ID) };
  }
  return { userId: String(CREATOR_ID) };
}

async function uploadPng(filePath, displayName) {
  const bytes = fs.readFileSync(filePath);
  const blob = new Blob([bytes], { type: "image/png" });

  const request = {
    displayName,
    description: `Courier bait game UI icon: ${displayName}`,
    assetType: "Decal",
    creationContext: {
      creator: buildCreator(),
      expectedPrice: 0,
    },
  };

  const form = new FormData();
  form.append("request", JSON.stringify(request));
  form.append("fileContent", blob, path.basename(filePath));

  const res = await fetch("https://apis.roblox.com/assets/v1/assets", {
    method: "POST",
    headers: {
      "x-api-key": API_KEY,
    },
    body: form,
  });

  const text = await res.text();
  let json;
  try {
    json = JSON.parse(text);
  } catch {
    throw new Error(`Upload failed (${res.status}): ${text}`);
  }
  if (!res.ok) {
    if (res.status === 401 || res.status === 403) {
      throw new Error(
        `Upload failed (${res.status}): ${text}\n` +
          `→ Key rejected by Roblox. Check Creator Dashboard:\n` +
          `  1) API Access → enable "Assets" (Read + Write)\n` +
          `  2) Accepted Users = your account\n` +
          `  3) IP Access = All IPs (or your current IP)\n` +
          `  4) Re-copy key with SINGLE quotes in PowerShell:\n` +
          `     $env:ROBLOX_API_KEY = 'paste_here'`
      );
    }
    throw new Error(`Upload failed (${res.status}): ${text}`);
  }

  return json;
}

async function pollOperation(operationIdOrPath) {
  let opId = String(operationIdOrPath);
  const pathMatch = opId.match(/operations\/([^/?]+)/);
  if (pathMatch) {
    opId = pathMatch[1];
  }
  opId = opId.replace(/^assets\/v1\//, "");

  for (let i = 0; i < 40; i++) {
    const res = await fetch(`https://apis.roblox.com/assets/v1/operations/${opId}`, {
      headers: { "x-api-key": API_KEY },
    });
    const json = await res.json();
    if (json.done) {
      return json;
    }
    await sleep(1500);
  }
  throw new Error(`Timeout polling operation ${opId}`);
}

function extractAssetId(payload) {
  const direct =
    payload?.response?.assetId ||
    payload?.assetId ||
    payload?.id ||
    payload?.Response?.assetId;
  if (direct) return String(direct);

  const pathStr = payload?.path || payload?.response?.path || "";
  const m = String(pathStr).match(/assets\/(\d+)/);
  if (m) return m[1];

  if (payload?.done && payload?.response) {
    return extractAssetId(payload.response);
  }
  return null;
}

async function main() {
  const files = fs
    .readdirSync(ICONS_DIR)
    .filter((f) => f.endsWith(".png") && !SKIP.has(f))
    .sort();

  console.log(`Found ${files.length} icons in ${ICONS_DIR}`);
  console.log(`Creator: ${JSON.stringify(buildCreator())}`);

  const ids = {};
  if (fs.existsSync(OUT_MODULE)) {
    const prev = fs.readFileSync(OUT_MODULE, "utf8");
    for (const match of prev.matchAll(/(\w+)\s*=\s*"rbxassetid:\/\/(\d+)"/g)) {
      ids[match[1]] = `rbxassetid://${match[2]}`;
    }
  }

  for (const file of files) {
    const key = file.replace(/\.png$/i, "");
    if (ids[key]) {
      console.log(`skip (exists) ${key}`);
      continue;
    }

    const full = path.join(ICONS_DIR, file);
    process.stdout.write(`upload ${key}... `);
    try {
      let result = await uploadPng(full, key);
      let assetId = extractAssetId(result);

      if (!assetId && (result.path || result.operationId || result.name)) {
        const op = result.operationId || result.path || result.name;
        result = await pollOperation(op);
        assetId = extractAssetId(result);
      }

      if (!assetId) {
        console.log("FAILED (no assetId)", JSON.stringify(result).slice(0, 300));
        continue;
      }

      ids[key] = `rbxassetid://${assetId}`;
      console.log(ids[key]);
      // Persist progress after each success so a mid-run fail keeps IDs
      writeModule(ids);
      await sleep(800);
    } catch (err) {
      console.log("ERROR", err.message || err);
      await sleep(1000);
    }
  }

  writeModule(ids);
  console.log(`\nWrote ${Object.keys(ids).length} ids → ${OUT_MODULE}`);
}

function writeModule(ids) {
  const lines = Object.keys(ids)
    .sort()
    .map((k) => `\t${k} = "${ids[k]}",`);

  const moduleSrc = `--!strict
-- AUTO-GENERATED by tools/upload-icons.mjs — do not edit by hand unless fixing IDs.

local IconAssetIds = {}

IconAssetIds.Ids = {
${lines.join("\n")}
} :: { [string]: string }

return IconAssetIds
`;

  fs.writeFileSync(OUT_MODULE, moduleSrc, "utf8");
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
