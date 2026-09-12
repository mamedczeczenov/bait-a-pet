import { createRequire } from "node:module"
import fs from "node:fs"
import path from "node:path"
import { fileURLToPath } from "node:url"

const require = createRequire(import.meta.url)
const { RobloxFile } = require("rbxm-parser")

const __dirname = path.dirname(fileURLToPath(import.meta.url))
const petsDir = path.join(__dirname, "..", "assets", "pets")

const ROSTER = [
	// Common 15
	"Doggy",
	"Kitty",
	"Bunny",
	"Fox",
	"Chicken",
	"Piggy",
	"Ducky",
	"Penguin",
	"Marshmallow",
	"Teddy Bear",
	"Balloon Kitty",
	"Classic Fox",
	"Classic Mouse",
	"Blue Ducky",
	"Bear Plushie",
	// Uncommon 10
	"Dowodle",
	"Beach Bat",
	"Coral Kitty",
	"Ocean Kitty",
	"Palm Bear",
	"Sandy Wolf",
	"Snowy Fox",
	"Peppermint Doggy",
	"Summer Shark",
	"Blueberry Deer",
	// Rare 8
	"Amethyst Bear",
	"Crystal Bunny",
	"Emerald Doggy",
	"Chocolate Bear",
	"Gummy Shark",
	"Honey Comb Bee",
	"Magic Panda",
	"Ghost Kitty",
	// Epic 6
	"King Doggy",
	"Lunar Fox",
	"Queen Bee",
	"Water Golem",
	"Rainbow Butterfly",
	"Ghost Doggy",
	// Legendary 5
	"Atlantis Guardian",
	"Manticore",
	"Void Fox",
	"Inferno Cube",
	"Radiant Protector",
	// Mythic 4
	"Atlantis Pegasus",
	"Magma Hybrid",
	"Night Dweller",
	"Rainbow Shock",
	// Angelic 3
	"Holy Bee",
	"Holy Shock",
	"Lunarcorn",
	// Glorious 2
	"Atlantis Overlord",
	"Infernal Master",
	// Radiant 2
	"Rainbow Drag",
	"King Pufferfish",
	// Secret 2
	"Night Terror",
	"King Eye",
	// Eternal 2
	"Giant Robot",
	"Sylently's Pet",
	// Divine 1
	"Void Dragon",
]

function prop(inst, key) {
	const p = inst._props && inst._props.get(key)
	return p ? p.value : undefined
}

function className(inst) {
	const list = inst._classNameList || []
	return list[list.length - 1] || "Instance"
}

function children(inst) {
	return [...(inst._children || [])]
}

if (ROSTER.length !== 60) {
	throw new Error(`Roster must be 60, got ${ROSTER.length}`)
}

const file = RobloxFile.ReadFromBuffer(fs.readFileSync(path.join(petsDir, "pets.rbxm")))
const want = new Set(ROSTER)
const root = file.Roots[0]
const byName = new Map()

for (const child of children(root)) {
	if (className(child) !== "Model") continue
	const name = prop(child, "Name")
	if (want.has(name)) byName.set(name, child)
}

const missing = ROSTER.filter((n) => !byName.has(n))
if (missing.length > 0) {
	throw new Error(`Missing models: ${missing.join(", ")}`)
}

for (const child of [...children(root)]) {
	child._parent = undefined
	root._children.delete(child)
}

root._children = new Set()
for (const name of ROSTER) {
	const model = byName.get(name)
	model._parent = root
	root._children.add(model)
}
root._props.get("Name").value = "Pets"

const out = file.WriteToBuffer()
fs.writeFileSync(path.join(petsDir, "map1-pets.rbxm"), out)
fs.writeFileSync(path.join(petsDir, "map1-roster.json"), JSON.stringify(ROSTER, null, 2))

const verify = RobloxFile.ReadFromBuffer(out)
const names = children(verify.Roots[0])
	.filter((c) => className(c) === "Model")
	.map((c) => prop(c, "Name"))

console.log(`Wrote map1-pets.rbxm (${out.length} bytes), ${names.length} models`)
if (names.length !== 60 || names.some((n, i) => n !== ROSTER[i])) {
	throw new Error("Verify failed: roster order mismatch")
}
console.log("OK")
