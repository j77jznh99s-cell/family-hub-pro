---
tags: [project, roblox, art, brief]
project: "[[Sproutling Isles]]"
owner_role: game-designer
status: draft-for-quote
updated: 2026-09-23
---
# Sproutling Isles: Art Brief

Brief for an outside 3D artist or Roblox modeler, written so you can quote from it. It covers the 13 Sproutlings,
mutation looks, the hatch animation, buildings, the UI kit, the icon and thumbnails. Back to [[Sproutling Isles]].

> **What exists today:** every Sproutling is built in code from primitive parts (a round body, a face, and one
> of 7 "topper" shapes). Colours come from `src/shared/Species.luau` and mutation colours from
> `src/shared/Weather.luau`. This brief replaces that look. The numbers (species, rarities, colours) are the
> current tunables and may still change.

---

## 1. The game in one paragraph (for the artist)
Players grow **Sproutlings**, small plant-creatures that hatch from seed pods in a soil patch. Each one sits on a
display pad in the player's greenhouse and earns **Dew** (the currency). Weather events can hatch **mutated**
Sproutlings (Golden, Dewy, Charged, Starry, Prismatic), and about 1 in 100 hatches is **Huge** (2.5x size).
Rivals can **snatch** a Sproutling and run home with it held over their head. Up to 8 players share an island.
The mood is a cosy garden with a cheeky twist.

## 2. Art direction
- **Original, cozy and cute.** Soft rounded shapes, chunky proportions (head and body are usually one shape),
  big simple eyes, blush cheeks. Plants and animals are *blended*: each Sproutling reads as "a plant that is
  also a little animal".
- **Originality rules (must follow):**
  - Don't imitate, trace or "homage" any character, creature, pet or prop from another game, film or toy line.
    Genre conventions (round cute critters, mushroom caps, glowing rares) are fine; specific designs are not.
  - Avoid the single leaf or flower on a thin stem growing from the top of the head. That motif is strongly
    tied to an existing franchise. Our plant parts are ears, manes, shells, caps, crests and tails instead.
  - Before sign-off, check every design side by side against the major creature franchises and the top
    Roblox pet and garden games. If a player could reasonably mistake one for an existing character, revise it.
  - No text, logos or real-world brands on models or textures.
- **Readable on phones first.** Most players are on phones, where a Sproutling on a pad is roughly 40 to 80 px
  tall on screen. Test every design as a flat black silhouette at 64 px and in-game at 30 studs' distance.
- **Flat colour with soft shading.** Bodies are solid-colour MeshParts (so code can tint them for mutations),
  with a small texture only for the face. No photo textures and no realistic PBR on creatures.
- **Rarity ladder.** Common = 1 to 2 colours and simple shapes. Rare = an extra accent colour and one animated
  part. Epic = a distinctive silhouette and a small emissive detail. Legendary = emissive accents and flowing
  parts. Mythic and Secret = they float above the pad and have orbiting pieces. A player should be able to guess
  the rarity from across the greenhouse.

### Technical budgets (Roblox, mobile-safe)
| Asset | Triangle target (max) | Parts if built from parts | Textures |
| --- | --- | --- | --- |
| Common Sproutling | 800 to 1,500 (2,000) | 25 or fewer | 1 face atlas (shared) |
| Uncommon / Rare | 1,200 to 2,000 (2,500) | 35 or fewer | shared face atlas |
| Epic / Legendary | 2,000 to 3,000 (3,500) | 45 or fewer | shared face atlas + 1 emissive mask (optional) |
| Mythic / Secret | 2,500 to 3,500 (4,000) | 50 or fewer | shared face atlas + 1 emissive mask |
| Seed pod (4 growth stages) | 300 to 600 per stage | 10 or fewer | none (tinted in code) |
| Greenhouse (per plot) | 6,000 (10,000) | 150 or fewer | 1 x 512 trim sheet (shared) |
| Gate + lock button | 2,000 (3,000) | 40 or fewer | shared trim sheet |
| Plaza building (each stall) | 3,000 to 5,000 (8,000) | 120 or fewer | shared trim sheet |

- Worst case on screen: 8 plots x 12 pads = 96 Sproutlings. At about 2,000 tris each that is about 200k tris,
  so rely on MeshPart `RenderFidelity = Automatic` (level of detail) and keep to the targets.
- A single mesh must stay under Roblox's per-mesh triangle limit (currently about 20k, but check the Creator
  Hub). Our targets are far below it.
- Textures: 512 x 512 PNG by default, 1024 max. Anything larger is downscaled by Roblox anyway.
- Scale: 1 unit = 1 stud. Pivot at the **feet** (bottom centre). The face looks along **-Z**. The code already
  assumes both (see `SproutModel.luau`).

## 3. Palette
### World
| Use | Hex |
| --- | --- |
| Plaza stone (warm cream) | `#E1D7C3` / `#EBE1CD` |
| Soil | `#6E4B32` |
| Grass / hedge sage | `#78AA5A` / `#46823C` |
| Dew / water accent | `#78DCFF` (fountain drop `#5AB4F0`) |
| Greenhouse glass tint | `#DFF3EA` at about 60% transparency |
| Wood trim | `#B98A5E` / `#8A6242` |
| Roof moss / terracotta | `#6E9E55` / `#D07A55` |

### Rarity colours (from `Species.RarityColors`, used for name labels, frames, beams)
| Common | Uncommon | Rare | Epic | Legendary | Mythic | Secret |
| --- | --- | --- | --- | --- | --- | --- |
| `#BEBEBE` | `#6ED26E` | `#50A0FF` | `#B464FF` | `#FFBE28` | `#FF508C` | `#28FFE6` |

### Mutation colours (from `Weather.Mutations`)
| Golden | Dewy | Charged | Starry | Prismatic |
| --- | --- | --- | --- | --- |
| `#FFCD32` | `#78C8FF` | `#FFFF6E` | `#BEAAFF` | `#FF78E6` (cycles through all hues) |

## 4. Silhouette rules
1. Each species has one **body family** (ball, bean, pear, long, tall-slim, floating) and one **plant feature**
   (leaf ears, sprig, clover, bud, spines, cap, pad, thorn crest, petals, flame mane, orchid wings, crystal).
   No two species share both.
2. The plant feature makes up 25 to 40% of the silhouette. It is the first thing you recognise.
3. Eyes sit in the top third, facing -Z. Keep a clear face area. Nothing covers the eyes from the front camera.
4. Footprint: base width 6 studs or less, so that Huge (2.5x) is 15 studs or less. Pads are 9-stud discs; Huge
   is meant to overhang.
5. No thin parts under 0.2 studs at base size (they shimmer on phones). Spines and whiskers are chunky and soft.
6. Mythic and Secret float 1 stud above the pad with a soft contact shadow disc, so they read as "special" from
   far away.
7. Carry pose: the model is welded 4.5 studs above a player's root when snatched, so it must look good seen
   from below and behind. Give it a "panicked flail" pose (see the animation list).

## 5. Species sheets (all 13)
Sizes are the height at base scale (Huge = x2.5). "Topper" names the tag used in code. Body and accent hex come from
`Species.luau` and can be shifted slightly for good looks, but keep the hue.

| # | Species (rarity) | Body / accent | Look | Personality | Topper (code tag) | Idle animation idea | Size (studs H x W) |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | **Mossbun** (Common) | `#78AA5A` / `#46823C` | A round moss-ball bunny with a fuzzy moss texture done as geometry bumps, not a texture. Its two long ears are broad leaves, and its tail is a dandelion-fluff puff. | Sleepy, content | Leaf, as leaf ears (not a stem on the head) | Slow breathing squash, ears droop and then perk up, occasional nibble | 3.0 x 3.0 |
| 2 | **Pebblepup** (Common) | `#9696A0` / `#5AA050` | A smooth river-stone puppy with stubby legs. A tiny three-leaf sprig grows from a crack in its back, and it has a pebble tail. | Loyal, excitable | Leaf, as a back sprig | Tail wag, two quick hops, sniffs the ground | 3.0 x 3.5 |
| 3 | **Clovercub** (Common) | `#5AC86E` / `#28963C` | A chubby bear cub. Its round ears are three-lobed clover leaves, and a four-leaf patch on its belly is the luck motif. | Lucky, clumsy | Petals, as clover ears | Sits, rocks backwards, rolls upright | 3.5 x 3.5 |
| 4 | **Tulipaca** (Uncommon) | `#FAEBD7` / `#F05A78` | A fluffy cream camelid shape with a long neck. Its top-knot is a closed tulip bud that opens. | Prim, proud | Petals, as a tulip top-knot | Bud opens to show petals and closes, neck sway, chewing | 4.5 x 3.0 |
| 5 | **Cactoad** (Uncommon) | `#50A05A` / `#FAC850` | A squat toad with a cactus-pad body, soft rounded nub spines (never sharp) and a yellow cactus flower on its head. | Grumpy-cute | Spikes, as nub spines + flower | Throat puffs out, slow blink, one tiny hop | 3.0 x 4.0 |
| 6 | **Mushroomph** (Rare) | `#F0E1C8` / `#D23C3C` | A stout, stubby-legged "mushroom mole" with a big round snout and digging paws. It wears a wide red cap with cream **dewdrop-shaped** spots (not round dots). It is a four-legged creature, not a humanoid. | Show-off strongman | Cap | Rears up and "flexes" its paws, cap bounces, spore puff | 4.0 x 5.0 (cap) |
| 7 | **Lilypadger** (Rare) | `#466E5A` / `#6EC878` | A badger with water-green stripes and a flat lily pad on its back like a raft, with a pink bud on the pad. Its fur looks damp. | Calm, a brave pond-keeper | Pad | Shakes water off (droplet particles), bud blooms, settles | 3.5 x 4.5 |
| 8 | **Thornix** (Epic) | `#5A2846` / `#C8285A` | A plum bramble fox-lynx with a crest of soft rose-thorn quills and a tail ending in a rose bud. It has a sly grin. | Mischievous, a bit edgy (for older players) | Spikes, as a thorn crest | Tail swish, crest bristles in a wave, side-eye | 4.5 x 4.0 |
| 9 | **Bloomingo** (Epic) | `#FF96BE` / `#FFF078` | A tall wading bird made of layered blossom petals, standing on one stem-leg, with a pollen-puff crest. | Dancer, show-off | Petals, as a petal body + crest | Balances on one leg, twirls, a few petals fall | 5.0 x 2.5 |
| 10 | **Sunfloof** (Legendary) | `#FFD25A` / `#FF8C1E` | A round golden fluffball with a sunflower-petal mane. The petal tips glow (emissive) like soft flames. | Cheerful, radiant | Flame, as a petal mane | Mane ripples like fire, beams, slowly turns to face the sky | 5.0 x 5.0 |
| 11 | **Orchidragon** (Legendary) | `#AA78DC` / `#FAFAFF` | A small hovering wyrmling. Its wings are white orchid petals, it has whisker tendrils, and it has a lavender body with a soft gradient. | Noble, gentle | Petals, as orchid wings | Hovers low, wings flutter, curls its tail, breathes a pollen puff | 5.5 x 5.0 |
| 12 | **Moonpetal Wisp** (Mythic) | `#C8DCFF` / `#788CFF` | A floating crescent-moon petal spirit, part translucent, with a small face inside the crescent and blue crystal shards orbiting like petals. | Shy, dreamy | Crystal, as orbiting shards | Floats 1 stud up and bobs, shards orbit slowly, fades to 30% transparency and back | 5.5 x 4.0 |
| 13 | **Starseed Sprite** (Secret) | `#1E1E3C` / `#50FFE6` | A navy night-sky seed shell, cracked open, with a teal glowing sprite inside (stubby arms, big eyes). The two shell halves float around it and the shell has star specks. | Mysterious, curious | Crystal, as the shell halves + star specks | Shell halves orbit, constellation lines flicker between the specks, sprite peeks out | 5.0 x 4.5 |

**Face atlas (shared, 512 x 512):** 8 expressions for all species: idle, blink, happy (^ ^), surprised
(hatch), scared (being snatched), sleepy, proud, sparkle-eyes (rare hatch). Use flat colours, a dark-ink
outline and one white highlight per eye.

**Animations per species (Roblox Animation assets, looping where marked):**
`Idle` (loop, 3 to 5 s), `Happy` (1 s, played when placed on a pad or after a trade), `Carried` (loop, a panicked
flail while snatched), `HatchPop` (1 s, see section 7). Budget: 4 to 6 bones per creature. Play animations on the
client only.

### Growth stages (soil, shared by every species, tinted with the species accent colour in code)
1. Seed mound with a crack. 2. Sprout (2 small leaves). 3. Bud pod, wiggles now and then. 4. **Ripe pod** that
glows softly in the rarity colour and pulses, with a "Ready!" feel. Tiles are 12 x 12 studs. The pod is about
3 studs tall.

## 6. Mutation treatments and Huge
Mutations are applied **in code** on top of the species model, so the artist provides the effect assets and
the engineer wires them up. At most one mutation per Sproutling; Huge can combine with any mutation.

| Mutation (x Dew) | Body treatment | Particles / extras | Budget |
| --- | --- | --- | --- |
| **Golden** (x4) | Body swaps to a gold metallic material (`#FFCD32`) with a shine sweep every 3 s | 2 to 3 slow gold glints; a tiny crown-shaped sparkle over the head | 1 emitter, rate 3 or less |
| **Dewy** (x1.5) | 45% tint toward `#78C8FF` plus a glossy wet look (lower roughness) | A drip droplet from the chin every 2 s; a small puddle ring decal under the feet | 1 emitter, rate 1 or less |
| **Charged** (x2) | Tint toward `#FFFF6E`; neon zig-zag seams on the body (an extra mesh or decal) | A spark crackle every 1.5 to 2 s; the plant feature "frizzes" (scale jitter) | 1 emitter in bursts |
| **Starry** (x3) | Body darkens toward indigo with a star-speck overlay (`#BEAAFF` specks) | 3 tiny stars orbiting at head height | 3 small parts + 1 trail |
| **Prismatic** (x6) | Hue cycles through the rainbow over 4 s (driven by script); a soft outer shell glow | Rainbow aura ring on the ground; slow sparkle | 1 emitter + 1 beam ring |
| **Huge** (2.5x size) | Scale x2.5; idle plays at 0.7x speed (it feels heavy) | A dust puff on each hop; a ground shadow ring; a "HUGE" badge on the name label | none extra |

- Replace today's generic neon halo with these treatments. Keep a thin rarity-coloured rim on the pad.
- Particles run only within 60 studs of the camera (client toggles them), and each Sproutling gets at most
  2 emitters.
- Stacked example to mock up for sign-off: a **Golden Huge Thornix** and a **Prismatic Orchidragon**.

## 7. Hatch animation storyboard
Triggered when the player collects a ripe pod (the existing `Hatch` effect). Standard total: **2.5 s**. For
Legendary and above: **4 s**. Tapping anywhere after 1 s skips to the name card. Gameplay never pauses.

| Time | Shot | Sound cue |
| --- | --- | --- |
| 0.0 to 0.6 s | The ripe pod shakes in 3 quick wiggles; the camera nudges 10% toward the soil | Rustle, rising "boing" |
| 0.6 to 1.1 s | Cracks glow in the **rarity colour**; light leaks out | Crack tick x3 |
| 1.1 to 1.5 s | The pod pops open like petals unfolding; pollen puff; the Sproutling squashes flat in the pod | Pop |
| 1.5 to 2.0 s | It springs up (stretch), spins once and lands (squash) with the `surprised` then `happy` face | Chime (pitch rises with rarity) |
| 2.0 to 2.5 s | A name card slides up: species name in the rarity colour, rarity pill, Dew/s. The Sproutling hops to its pad | Short jingle |
| Mutation beat (+0.5 s) | If mutated: a flash of the mutation colour sweeps over the body, then the "GOLDEN!" word pops above the card | Mutation sting (one per mutation) |
| Huge beat (+0.5 s) | If Huge: it inflates in 3 steps with a camera shake (small), then "HUGE!" | Stretch "whomp" |
| Legendary+ (+1.5 s) | A vertical light beam in the rarity colour seen by the whole server; confetti petals | Choir swell |
| Secret | The screen edges darken, a starfield vignette, then the beam is teal. Card text: "SECRET!" | Unique sting |

Deliverables: 4 pod-stage meshes, a pod-open mesh (or 5 petal parts), 3 particle textures (pollen, petal,
sparkle), a beam texture, and the timing sheet above as a video mock-up (MP4 or GIF).

## 8. Buildings and world style
**Style:** chunky, bevelled "toy garden" architecture. Cream stucco, honey-wood trims, mossy or terracotta roofs,
rounded edges everywhere, oversized flowers as decoration. Use one shared 512 trim sheet and SmoothPlastic/Wood
materials so the kit is cheap to render.

| Piece | Brief |
| --- | --- |
| **Plot** (100 x 100 studs) | Hedges on 3 sides in the plot's colour trim; a 4 x 3 grid of soil tiles (12 x 12 studs); a stepping-stone path to the gate |
| **Greenhouse** (about 34 x 98 studs floor) | A long arched glass house with a wooden frame and 12 marble pads (9-stud discs, pads 9 to 12 marked "bonus" with a gold rim). The roof glass is transparent enough to see the Sproutlings from outside. The owner sign sits above the entrance |
| **Gate** | Two flower-topped pillars. The lock is a **glowing vine curtain** that grows across the opening when locked (replacing today's laser look), and the lock button is a giant daisy button that sinks when pressed. Both states must read clearly from 50 studs |
| **Bloom Plaza** (130-stud disc) | The Dewdrop Fountain (the centrepiece, a big glowing drop on a pillar); a Seed Shop market stall with 11 kiosks; the Sell Stand; the Rebirth Shrine (6 pillars + an orb); Daily Gift and Sprout Supply stalls; 8 lamps. Coming in Phase 2: **3 Trading Booths** (see [[Sproutling Isles - Trading Spec]]), small gazebos with two flower mats facing each other across a counter |
| **Other areas** | Pollen Parade conveyor (a vine belt with flower rollers), Wishing Pond (lily pads, stone rim, fishing spot), Sky Garden (floating island with a launch pad) |

The existing map layout in `MapBuilder.luau` sets the positions. The artist replaces the geometry, and named
anchor parts (such as `Anchor`, `Pad1`, `Kiosk3`) **must keep their names and rough positions** because scripts
look them up.

## 9. UI style guide
**Feel:** soft "sticker" UI: cream panels, chunky rounded buttons with a darker bottom lip, dark-ink outlines.

| Token | Value |
| --- | --- |
| Header font | `FredokaOne` (already used everywhere in code) |
| Body font | `BuilderSans` Medium/Bold (Roblox's current default family); fallback `Nunito` |
| Numbers (Dew) | `FredokaOne` with a 2 px dark stroke |
| Panel | `#FFF8EC`, stroke `#2E3A2F` at 3 px / 25% transparency, corner radius 12 px |
| Ink (text) | `#2E3A2F`; secondary `#6B7A6C` |
| Primary button | `#5CC86E` face with a `#3E9A4F` 4 px bottom lip, white text |
| Secondary button | `#50A0FF` / lip `#2F74C8` |
| Danger / cancel | `#FF6B6B` / lip `#C84848` |
| Robux / premium | `#FFBE28` / lip `#C88E10`, with the Robux icon |
| Dew accent | `#78DCFF` |
| Rarity pills | Rarity colours from section 3, with black text on light colours |

**Rules:**
- Tap targets are at least 48 x 48 px. The main HUD sits inside the device's safe area and never under the
  Roblox top bar.
- Minimum text size is 14 px on phone. Use `TextScaled` only together with a `UITextSizeConstraint`.
- Buttons press down 2 px (the lip shrinks) with a 0.08 s tween and a soft click sound.
- Icons are rounded, 2-tone, with a dark outline, 128 x 128 PNG exported at 2x. Needed: Dew, seed, Sproutling,
  shop, sell, lock, shield, weather (4), trade, gift, rebirth, settings, close, Robux.
- Toasts slide in from the top centre, stay 3 s, and are colour-coded (the existing `Notify` colours).

## 10. Game icon and thumbnails
- **Icon (512 x 512, no text):** a close-up of a Mossbun face peeking out of a cracked, glowing seed pod, with
  gold sparkles, on a bright leaf-green radial background. It must read at 50 px: big eyes, a strong outline,
  and only 3 main colours.
- **Thumbnail 1, "Hatch rares":** a player's hands-up reaction as a Prismatic Orchidragon bursts from a pod
  under an Aurora sky, with a rarity beam. Title text: "HATCH RARE SPROUTLINGS".
- **Thumbnail 2, "Snatch and defend":** a player sprinting away with a Golden Huge Sunfloof held overhead while
  the owner chases with a comic "BONK" motion line. The vine gate is closing behind them. Text: "SNATCH & DEFEND".
- **Thumbnail 3, "Weather = mutations":** a wide shot of the island during Starfall, with greenhouses glowing
  with Starry and Charged Sproutlings and meteors of light. Text: "WEATHER MAKES MUTATIONS".
- Size: 1920 x 1080 (16:9). Text goes in the safe middle 80%, with a strong outline, at most 4 words.
  Check the current icon and thumbnail specs on the Creator Hub before delivery (unverified here).

## 11. Deliverables and file formats
| # | Deliverable | Format |
| --- | --- | --- |
| 1 | 13 Sproutling models, rigged, pivot at the feet, facing -Z, 1 unit = 1 stud | `.fbx` per species (Roblox 3D Importer) plus the source `.blend` |
| 2 | An assembled Roblox model per species named `Sprout_<id>` (ids: `mossbun`, `pebblepup`, `clovercub`, `tulipaca`, `cactoad`, `mushroomph`, `lilypadger`, `thornix`, `bloomingo`, `sunfloof`, `orchidragon`, `moonpetal`, `starseed`). The parts inside are named `Body` (tintable), `Accent`, `Face` (decal or SurfaceAppearance), plus the attachments `TopAttachment` and `CarryAttachment`. PrimaryPart = `Body` | One `.rbxm` containing all 13 |
| 3 | Animations: Idle, Happy, Carried, HatchPop per species | Roblox Animation `.rbxm` (KeyframeSequence) or `.fbx` animation clips |
| 4 | Shared face atlas (8 expressions) and an optional emissive mask per Legendary+ | `.png` 512 x 512 |
| 5 | Mutation VFX kit: particle textures, the Starry overlay, the Charged seam mesh, the Prismatic aura | `.png` (256 to 512) + `.rbxm` with configured emitters |
| 6 | Growth-stage pods (4) + pod-open | `.fbx` + `.rbxm` |
| 7 | Building kit: greenhouse, gate + vine curtain (open and locked states), lock button, plot hedges, plaza stalls, fountain, shrine, trading booth, lamps | `.fbx` + `.rbxm`, one 512 trim sheet `.png` |
| 8 | UI kit: 9-slice panels and buttons (all states), icons, rarity pills | `.png` at 2x, plus a Figma (or similar) source file |
| 9 | Game icon + 3 thumbnails | `.png` 512 x 512; `.png` or `.jpg` 1920 x 1080; layered source |
| 10 | Hatch animation mock-up | `.mp4` or `.gif` |

**Accepted when:** each model is imported into a test place with no importer warnings; it is within its triangle
target; it faces -Z with the pivot at the feet; it reads at 64 px and at 30 studs on a phone; and no similarity
concerns are raised in review.

## 12. Rough effort estimate (unverified, for quoting only)
| Work | Hours (range) |
| --- | --- |
| Concept sheets for 13 species (front, side, expression) | 25 to 40 |
| Modelling 13 Sproutlings | 55 to 90 |
| Rigging + 4 animations each | 35 to 55 |
| Face atlas + mutation VFX kit | 15 to 25 |
| Growth pods + hatch animation + mock-up video | 15 to 25 |
| Building kit (greenhouse, gate, plaza, booths) | 35 to 60 |
| UI kit + icons | 25 to 40 |
| Icon + 3 thumbnails | 15 to 25 |
| Revisions and Roblox import checks (about 15%) | 30 to 50 |
| **Total** | **about 250 to 410 hours** |

The hours are the game-designer's estimate and have not been checked against real freelancer quotes. Costs depend
on the artist's rate. A sensible way to phase it: (1) species 1 to 3 + the face atlas as a paid test, (2) the rest
of the species + mutations, (3) buildings + UI, (4) icon and thumbnails last, once the look is locked.

## 13. What `roblox-engineer` must build to use this art (later task)
- `SproutModel.build` clones `ReplicatedStorage.SproutArt.Sprout_<id>` if it exists and otherwise falls back to
  today's primitives. It also removes the extra 1.4 base scale once real-size art is in.
- Mutation treatments go in a new `MutationFX` module on the client (particles only near the camera).
- Growth-stage pods replace the soil markers. The hatch sequence goes in the client `Hatch` effect handler.
- Map geometry is swapped while keeping every anchor name used by the services.
