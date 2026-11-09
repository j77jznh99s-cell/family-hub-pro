---
tags: [project, selling, game-assets]
status: first pack built, waiting on owner Studio test
updated: 2026-11-09
---
# Game Asset Store

Sell ORIGINAL game assets. The originality rule in [[Gumroad Digital Products]] section 1 applies in full: made from scratch by us, no other people's brands, characters or names in titles, tags or art, no PLR or resold content, real human review before anything is published. The owner publishes; agents never publish or set prices.

## Demand brief (2026-11-09)

**Method note:** built with `WebSearch` only. `WebFetch` of create.roblox.com failed (host not allowed in this session's network settings), so every Roblox rule below is **(search-summary only, unverified)**. No primary earnings data exists for any of the three lines; sales figures are anecdotes. Re-check each marketplace's own fee and AI page before the owner lists anything.

### 1. Roblox developer kits (Luau systems, Studio plugins)
- **Where it sells:** Roblox Creator Store (models and plugins), Gumroad, itch.io.
- **Creator Store rules (search-summary only, unverified):** USD, not Robux, for models and plugins; needs a seller account via Stripe (up to 7 days to approve); monthly payout; monthly cap per buyer-seller pair. Scripts are not sold alone, they ship inside a model or plugin. Price floor $2.99 for models, $4.99 to $249.99 for plugins. Sources: [Creator Store docs](https://create.roblox.com/docs/production/publishing/selling-on-the-creator-store), [DevForum announcement](https://devforum.roblox.com/t/creator-store-buy-and-sell-plug-ins-with-real-world-currency/2923445), [Tubefilter](https://tubefilter.com/2024/01/29/roblox-creator-store-fees/). Searched 2026-11-09.
- **Fee conflict (unresolved):** one result says creators get "100% of net proceeds" (only taxes and processing deducted); another says 10% deducted, 90% paid. Treat fee as **0% to 10% plus Stripe processing** until the owner reads the live docs.
- **Typical prices:** only comps found are Gumroad Roblox starters at $5 and $10 (from [[Gumroad Digital Products]] brief, 2026-09-26, search-summary only). No current Creator Store top-seller price list found. A [DevForum top-sellers analytics thread](https://devforum.roblox.com/t/analytics-top-selling-and-grossing-plugins-and-models-for-creator-store/3187401/18) exists, not opened.
- **Competition:** big free pool (toolbox models, DevForum open-source) but paid, well-documented, tested systems look thin. Weak signal, not measured.
- **Team fit:** strong. We already write Luau and have original systems in [[Sproutling Isles]] (waystones, daily tasks and streaks, bestiary). Gap: nothing is play-tested in Studio, so the owner must test before sale.

### 2. 2D pixel-art packs (itch.io first)
- **itch.io model:** seller sets the revenue share, default 10%, can be 0% to 30%+; payment processing is extra (about 2.9% + $0.30, third-party figure). Minimum price $1 for paid items. Sources: [itch.io docs](https://itch.io/docs), [GamingOnLinux 2015](https://www.gamingonlinux.com/2015/03/itch-game-store-announces-open-revenue-sharing/), searched 2026-11-09.
- **Prices:** many packs $1 to $6; forum range $1 to $30 (a 2021 anecdote, [itch.io thread](https://itch.io/t/1425337/advice-on-selling-assets-pixel-art)). Heavy 40-50% sale and bundle culture ([itch.io sale example](https://itch.io/s/186591/spring-assets-sale)). A price of exactly $5 appears in both the $0-5 and $5-15 filters.
- **Revenue for small sellers:** anecdotes only: about 30 to 50 euros per year per quality asset; one dev about $80 across 2025 from two packs ([itch.io post](https://itch.io/post/12750888)). Unverified.
- **What sells best:** no data found. Commonly cited: tilesets, character sheets, icon packs, UI kits (not confirmed here).
- **Competition:** very high; commenters call the pixel section "filled to the brim with low-quality listings".
- **Team fit:** weak. We can only render PNGs with Pillow/SVG, with no artist, so output would look procedural next to hand-drawn work. Icon sets are the most feasible, and they are the most crowded.
- Unity Asset Store and GameDev Market were not researched for 2D.

### 3. 3D low-poly model packs
- **Prices (search results, mixed dates):** itch.io $4.99+ (small) to $55 (mega pack) to $120 (3,656 models); Unity Asset Store $9.85 to $44; bundles of 21 to 28 packs at $19.99 to $49 ([Polyworks](https://offaxisstudios.itch.io/polyworks-complete-collection), [Low Poly Megapack](https://rg-poly.itch.io/low-poly-megapack-3in1/purchase), [Unity low-poly pack](https://assetstore.unity.com/packages/3d/props/exterior/simple-voxel-low-poly-models-pack-75749)). Packs are often discounted 70%.
- **Fees:** Unity Asset Store 70% to publisher, 30% to Unity, per third-party guides only ([guide](https://generalistprogrammer.com/tutorials/unity-asset-store-selling-guide-revenue)); the Provider Agreement itself was not opened, and a forum post hints at regional changes from 2026-04-01 (unverified). Fab: 88% to seller, 12% to Epic ([Game Developer](https://www.gamedeveloper.com/marketing/epic-to-unify-content-marketplaces-and-offer-creators-88-percent-revenue-cut)), launch-era source, not re-confirmed for 2026. Sketchfab not researched.
- **Competition:** saturated, with mega-packs and bundles setting price expectations.
- **Team fit:** poorest. No Blender, no modelling skills. Procedural meshes in Python (OBJ/glTF) are possible but would not match market quality.

### Licences and AI rules
- **Licences sellers use:** CC0 (free, no revenue lever) for free hooks; otherwise a custom commercial-use licence: use in commercial games allowed, no resale or redistribution of the raw files. Typical wording, not sourced here; we should write our own short licence text.
- **itch.io:** since Nov 2024 every asset page must be tagged "AI Generated" or "No AI". Tagging is required even if AI output was hand-edited; untagged AI assets lose browse indexing. ([PC Gamer](https://pcgamer.com/software/platforms/indie-distribution-platform-itch-io-now-requires-asset-creators-to-disclose-the-use-of-generative-ai-in-their-work), [GamingOnLinux](https://gamingonlinux.com/2024/11/itchio-store-now-requires-ai-generated-content-disclosures-for-assets)). Whether pure code-generated (procedural) art counts as "AI" is not addressed in what I found. Our agents are AI, so the honest course is to tag **AI Generated** for anything an AI authored.
- **Unity Asset Store:** AI-generated content allowed if it does not resemble third-party work and has real value; disclosure is expected. Only the legacy policy page (superseded 2024-12-04) was seen ([Unity support](https://support.unity.com/hc/en-us/articles/16456407029524)). Check the current page.
- **Fab:** AI content allowed if tagged "CreatedWithAI"; buyers complain of weak enforcement ([Unreal forums](https://forums.unrealengine.com/t/update-on-products-generated-with-ai/2523501?page=2)). Search-summary only.
- **Roblox Creator Store:** no AI rule found; not checked.

### Side by side
| | Roblox Luau kit | 2D pixel pack | 3D low-poly pack |
| --- | --- | --- | --- |
| Price | $5-$25 (thin evidence); plugin floor $4.99 | $1-$6 typical | $5-$55, bundles cheaper |
| Fees | Gumroad 10% + $0.50; Creator Store 0-10% (conflicting) | itch.io 10% default + processing | Unity 30%; Fab 12% |
| Competition | Free toolbox; paid thin | Very high | High |
| Team can make well | Yes (code) | Marginal | No |
| Blocker | Studio test by owner | Quality vs hand-drawn | No tooling |

## Recommendation
Build **one Roblox Luau systems kit first: "Daily Tasks and Streaks" (or a 3-system starter: streak tasks, waystone fast-travel, bestiary journal)**, original code extracted from our own Sproutling Isles work, with a README, config file and example place layout.
- **Price:** $9.99 launch ($12.99 later). Gumroad direct sale nets about $8.49 after 10% + $0.50.
- **Store:** Gumroad plus itch.io first (no Studio needed to list). Add the Creator Store as a model only after the owner runs it in Studio and approves.
- **Why:** it is the only line where our output (tested, documented code) can beat the competition; the other two put a code-only team against artists in saturated markets at $1-$6.
- **Do not claim** it is tested until the owner has run it in Studio. Gumroad brief comps ($5-$10) are unverified, so treat $9.99 as a test price and judge after 30 days.
- Pixel icon pack is the fallback second product (cheap to render, $3-$5, tag AI Generated).

## First pack: Daily Streaks Kit (built 2026-11-09)
- **Where:** branch `claude/elegant-carson-k0ja0u`, folder `products/game-assets/daily-streaks-kit/`.
- **What:** game-agnostic Roblox Luau kit: 3 daily tasks per player from a config pool, rewards, an all-done bonus, a streak with a milestone every 5 days, DataStore saving (retries, autosave, shutdown save, no save after a failed load), a code-built panel for phone, PC and console, task-board tag, and signals for custom rewards. Rojo project, README, licence (commercial use OK, no resale), example script, and unit tests for the pure logic.
- **Origin:** rewritten from our own Sproutling Isles `DailyService`/`DailyTasks` (original code, no game names left in it).
- **Store copy:** `LISTING.md` in the kit folder ($9.99; itch.io AI disclosure: "AI Generated").
- **Not verified:** nothing has been run. The Luau CLI couldn't be run in the sandbox (blocked), so `tests/Logic.spec.luau` hasn't been run, and nothing has been tested in Studio.

## Tasks
- [x] market-researcher: demand brief (2026-11-09).
- [x] roblox-engineer (main session): build the Daily Streaks Kit (2026-11-09).
- [ ] **Owner:** run `luau tests/Logic.spec.luau`, Studio play-test (see the checklist in `LISTING.md`), take 3 screenshots.
- [ ] **Owner:** create Gumroad and itch.io accounts (if not done), then upload the zip and publish at $9.99.
- [ ] **Owner:** confirm Creator Store fee and AI rules on the live docs before listing there.
- [ ] qa-tester: code review of the kit and originality check ([[Gumroad Digital Products]] section 6).
- [ ] roblox-engineer: pack 2 candidates (waystone fast-travel kit, bestiary/journal kit), or a 3-in-1 bundle at about $19.99 once pack 1 has sales data.
- [ ] market-researcher: open the DevForum top-sellers thread and real Gumroad/itch.io Roblox kit listings for comps when the network allows.
