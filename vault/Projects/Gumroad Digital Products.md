---
tags: [project, selling, automation]
status: planning (owner approved 2026-09-26)
updated: 2026-09-26
---
# Gumroad Digital Products

## 1. Originality rule (read first, applies to every product)
**Every product we sell is original.** This rule comes before everything else in this plan.
- **Made by us, from scratch:** our own writing, layouts, designs and code. Never copied, resold, "rebranded" or lightly edited from someone else's product.
- **No other people's brands or characters:** no trademarks, logos, franchise names, characters, celebrity names or "inspired by" knock-offs in the product, title, images or tags.
- **No private label rights (PLR) or resell packs**, and no scraped content.
- **AI is a helper, not the author:** agents may draft, but every product gets real human review and changes. The listing says honestly what the product is.
- **Before approval**, each product passes the originality check in section 6. If in doubt, we don't publish.
- The same spirit as our house rule for games (`CLAUDE.md`): borrow the *type* of product (for example "a weekly planner"), never someone else's actual product.

## 2. The goal
Sell original digital products on Gumroad (downloads: templates, guides, printables), run by the StarNet agent crew
from [[StarNet Automation]]. Agents research and draft; the owner approves and publishes.

## 3. Costs (checked 2026-09-26)
| Item | Cost |
| --- | --- |
| Gumroad account | $0, no monthly fee |
| Gumroad fee, direct sale (buyer comes from your own link) | **10% + $0.50** per sale |
| Gumroad fee, sale through Gumroad Discover (its marketplace) | **30%** per sale |
| Card processing | Some guides say ~2.9% + $0.30 extra; check the Gumroad dashboard |
| StarNet agents | From the existing $5/day Anthropic budget |

Because of the $0.50 fixed fee, **price products at $5 or more** (a $2 product loses about a third to fees).

## 4. What to sell first (the research agent checks demand before we build)
Starter ideas that we can make genuinely original:
1. **Family organization printables**: chore charts, weekly planners, meal planners (fits the [[Family Hub]] idea).
2. **Beginner Roblox game-making guides**: written from our own experience building [[Sproutling Isles]], with our own example code. The guides teach; they don't sell the game itself or copy other games.
3. **Spreadsheet or Notion templates**: budget trackers, habit trackers, content calendars.

Pick **one** to start. Launch 3 products in it, learn, then add more.

## 5. One-time setup (owner, about 20 minutes)
1. Create a Gumroad account, confirm your email, and add a payout method (bank or PayPal). Gumroad only lets you publish after both.
2. Gumroad → Settings → Advanced → create an **application access token**.
3. In StarNet: TOOLSETS & CONNECTORS → KEYS → **Gumroad** → paste the token. Approve it for unattended use only for **reading sales**.
4. Never paste the token into the vault, the repo or a chat.

## 6. How the crew works (StarNet room: Product Studio)
| Step | Who | Model | What happens |
| --- | --- | --- | --- |
| 1. Research | market-researcher | Sonnet 5, medium | Finds product types people already buy; checks prices and reviews; writes a short brief with sources |
| 2. Make | product-maker | Sonnet 5, medium | Drafts the original product, title, description, tags and price, as files in the OUTBOX |
| 3. Originality check | qa-tester | Sonnet 5, medium | Runs the checklist below and writes pass/fail with reasons |
| 4. Approve and publish | **owner** | — | Reviews, edits, and uploads to Gumroad from its dashboard |
| 5. Track | knowledge-keeper | Haiku 4.5 | Weekly: reads sales (read-only) and summarizes what sells |

**Originality checklist (step 3):**
- [ ] Written and designed from scratch (no copied text, images, layouts or code).
- [ ] No trademarks, brands, characters, celebrity names or franchise references anywhere (product, title, images, tags).
- [ ] A web search for the title and key phrases finds no near-copy.
- [ ] The listing honestly describes what the buyer gets; no fake reviews, fake scarcity or income claims.
- [ ] The owner has reviewed and edited it.

## 7. Guardrails
- **The owner publishes.** Agents never publish, change prices, give refunds or email buyers without the owner's OK.
- Gumroad's API can create products (added recently, and the docs disagree), but we **don't use it** until the owner decides otherwise.
- Budget: research and making run on demand inside the $5/day cap. Only one scheduled job: the weekly sales summary.
- No income is guaranteed. We judge each product after 30 days.

## Demand brief (2026-09-26)

**Method note:** built with `WebSearch` (works in this sandbox) plus `WebFetch` attempts on individual Gumroad listings and Etsy category pages, which were blocked by the egress proxy (Etsy, individual `*.gumroad.com` product pages) or returned only search-engine snippets. Anywhere a figure is not independently confirmed from a page I could actually open, it's marked **(search-summary only, unverified)** — treat those as directional, not precise. This brief lays out evidence for the owner to weigh against the tentative pick in [[Decisions]] #20; it does not re-decide it.

### 1. Family organization printables (chore charts, weekly/meal planners)

- **Demand signal:** Etsy runs dozens of live category pages for this exact niche (`chore_chart_printable`, `chore_chart_template`, `meal_plan_printable`, `weekly_meal_planner`, etc. — [etsy.com/market/chore_chart_printable](https://www.etsy.com/market/chore_chart_printable), [etsy.com/market/meal_plan_printable](https://www.etsy.com/market/meal_plan_printable), as-of 2026-09-26, page contents from search snippets only, direct fetch blocked). Aggregator commentary (not primary data) describes the Etsy digital-planner/printable market as having grown into a "multi-billion dollar industry" with sellers reporting $500–$50,000+/month — [Outfy: 27 Top Selling Digital Products on Etsy in 2026](https://www.outfy.com/blog/top-selling-digital-products-on-etsy/) **(search-summary only, unverified; no primary revenue data behind this)**.
- **Price points:** simple printables (single chart, small planner) $5–$15; bundles/spreadsheet-integrated planners $20–$50 — same Outfy summary, 2026-09-26. Gumroad fee on a $5–$15 direct sale is 10% + $0.50 (per section 3 above), so a $8 chore chart nets roughly $6.70.
- **Competition:** high at the generic end — "chore chart," "meal planner," and "weekly planner" each have many active Etsy category pages and (per trend-tool commentary) thousands of competing listings; niche-specific angles (e.g., ADHD-friendly, budget-tracker-integrated) reportedly see "2–4X higher prices and 80% less competition" than generic versions — [Insight Agent: Best Selling Printables on Etsy 2026](https://www.insightagent.app/trends/etsy-printables) **(search-summary only, unverified — this is a trend-tool marketing page, not raw marketplace data)**.
- **Originality:** lowest brand-collision risk of the three lines — a chore chart or meal planner has no franchise/IP surface to accidentally copy. The real originality work is design/layout (colors, icons, typography) and the specific system (e.g., a streak/reward mechanic), not concept. The team's [[Family Hub]] project already has original family-organization content (streaks, XP, badges, favorites — see `FamilyHub/README.md` on `claude/family-hub-widget-1w7cv9`) that could inform a printable's *reward system* without copying app code or UI.
- **Effort given this team's assets:** [[Family Hub]] gives conceptual material (streak/reward mechanics for family routines) but that's an iOS app, not a print/PDF design skill — nothing in `vault/Projects/` shows the team has produced a finished print-ready PDF or used a layout tool (Canva, Affinity, etc.) before. `product-maker` can draft text/content and structure, but turning that into a polished, print-ready PDF is a real, unverified gap — flag this as a task for whoever builds product 1 to confirm a layout tool/workflow exists before promising a launch date.

### 2. Beginner Roblox game-making guides (from the Sproutling Isles build)

- **Demand signal:** Roblox's developer base is large — **3.5 million developers** as of Q3 2025, of whom Roblox's own DevEx data shows only ~35,500 registered in the Developer Exchange Program and ~23,500 actually paid out by 2025-12-31 — [Backlinko: Roblox User and Growth Stats 2026](https://backlinko.com/roblox-users), as-of 2026 **(figures attributed to Roblox's own reporting via this secondary source; I could not open roblox.com directly — blocked per `vault/Playbooks/Environment Setup.md`)**. That gap (millions of aspiring developers, thousands of monetized ones) is the addressable market for a beginner guide. Organic demand is visible directly on Roblox's own DevForum, which has a constant stream of beginner "how do I start scripting" threads (e.g., [devforum.roblox.com/t/what-should-i-do-first-to-learn-scripting/1534049](https://devforum.roblox.com/t/what-should-i-do-first-to-learn-scripting/1534049), [.../t/how-to-start-scripting/2524529](https://devforum.roblox.com/t/how-to-start-scripting/2524529) — found via search snippet only, devforum.roblox.com itself is on the blocked-host list).
- **Price points:** comparable Gumroad listings found via search: "Roblox Game Starter Kit – Build Your First Game Fast (No Coding)" at **$5** (digitalgoodsbyinga.gumroad.com) and "Ultimate Roblox Luau Developer Bundle" at **$10** (codersstop.gumroad.com) — both **(search-summary only, unverified — direct fetch of both listing pages was blocked by the egress proxy)**. Traditionally published Roblox dev books (Pearson's official "Roblox Game Development in 24 Hours," a few independent Amazon Kindle guides) exist at higher price points but I could not confirm exact prices without an Amazon fetch, so no number is claimed here.
- **Competition:** the *free* competition is intense — DevForum tutorials, YouTube channels (e.g., AlvinBlox per search results) and free courses cover the same beginner-scripting ground the team's guide would cover, per [Class Central: 8 Best Roblox Scripting Courses for 2026](https://www.classcentral.com/report/best-roblox-scripting-courses/), 2026. *Paid* competition on Gumroad specifically looks thinner and lower-quality (the two comps found are $5–$10, generic-sounding bundles). One aggregator claims Gumroad's "Writing & Publishing" category (which a written guide would likely fall under) has the highest revenue-per-product of any normal category — $15,750/product across 226 products, median 41 sales, "least competition" — [Medium: 14 Best Digital Products to Sell on Gumroad in 2026](https://medium.com/write-your-world/14-best-digital-products-to-sell-on-gumroad-in-2026-eda7b5b75e0b) and a similar figure surfaced from accio.com **(both search-summary only, unverified; the accio.com page itself is blocked by the egress proxy, so this could not be confirmed on the primary page)**.
- **Originality — the real constraint for this line:** a *generic* "how to make a Roblox game" guide would be indistinguishable from the free DevForum/YouTube content above, which is a real risk (the qa-tester originality check requires the listing to not read as a near-copy of existing free content, and a genuinely differentiated guide needs specifics, not repackaged basics). What this team could concretely and honestly write that others can't: the real [[Sproutling Isles]] build — a documented, dated QA pass with an actual blocker + 6 major bugs found and fixed (see `vault/Projects/Sproutling Isles - QA Review.md` and the Bugs section of `vault/Projects/Sproutling Isles.md`), a real Rojo/Lune/Selene CLI toolchain workflow (no Roblox Studio in the build sandbox — see `vault/Playbooks/Environment Setup.md`), a real analytics-wrapper build with pcall-guarded calls, and real design decisions with stated reasons (in [[Decisions]]). **Important honesty constraint:** as of 2026-09-26 the game is still "**not play-tested in Studio**" and unlaunched (`vault/Projects/Sproutling Isles.md` status: `build-1-untested`) — a guide cannot honestly claim "how we shipped a hit game," only "how we're building one, warts and QA process included," until there's a post-launch or at least a post-playtest chapter to add.
- **Effort given this team's assets:** this is the one line where source material already exists in the vault (the Design Doc, QA Review, Launch & Live Ops plan, Trading Spec, and the Decisions log). A first draft is largely a synthesis/rewrite task rather than new research, which is a real speed advantage over the other two lines — but it can't be finished and honestly marketed until at least one real Studio play-test has happened (currently the top blocked item in [[Active Context]]), or the "from our own experience" framing becomes a stretch.

### 3. Spreadsheet / Notion templates (budget trackers, habit trackers, content calendars)

- **Demand signal:** reported creator earnings are wide-ranging and top-heavy — most active creators $500–$3,000/month, a minority with an audience (YouTube/newsletter) reportedly $5,000–$50,000+/month, with named outliers like Thomas Frank ($1M+ lifetime Notion template sales) and Easlo (reported six-figure business) — [BizToolkit: Notion Template Creator Earnings in 2026](https://www.biztoolkit.co/post/how-much-do-notion-template-creators-make-in-2026), [Roqstar: Can You Still Make Money with Notion Templates in 2026?](https://roqstar.io/blog/can-you-still-make-money-with-notion-templates-in-2026) **(search-summary only, unverified — these are aggregator/marketing blogs quoting each other, not Notion's or Gumroad's own figures; heavy survivorship bias likely)**.
- **Price points:** Notion templates commonly $10–$97 per the same aggregator sources; spreadsheet budget trackers found directly on Gumroad at **$3.99** (marchborns.gumroad.com) and **$6.99+** (aitbahadi.gumroad.com — this second listing is explicitly sold as "PLR License + Bonus," i.e. resellable/private-label content, which is exactly the category of product the team's own originality rule (section 1) forbids making, though not forbids competing against) — both listing prices **(search-summary only, unverified; direct fetch blocked)**.
- **Competition:** described as saturated at the generic end — **50,000+ Notion template listings on Etsy** reported, with top "student planner"/"life OS" listings showing 1,000–3,500+ reviews, making generic entries very hard to rank against; niche, profession-specific templates (not generic budget/habit trackers) are reported as the remaining open space — [Kupkaike: Best-Selling Notion Templates on Etsy & Gumroad in 2026](https://kupkaike.com/blog/best-selling-notion-templates-etsy-gumroad-2026), [Kupkaike: Is Selling Notion Templates Still Profitable in 2026?](https://kupkaike.com/blog/is-selling-notion-templates-still-profitable-2026) **(search-summary only, unverified)**. The specific ideas listed in section 4 above — budget tracker, habit tracker, content calendar — are named in these sources as the *most* generic, most saturated sub-categories, not the niche ones reported to still have room.
- **Originality:** lowest IP/brand-collision risk (same reasoning as printables — a budget tracker has no franchise surface), but the highest genericity risk of the three: without a specific angle, "budget tracker" and "habit tracker" are the exact terms flagged above as the most crowded, least-differentiated corner of this market.
- **Effort given this team's assets:** confirmed by checking `vault/Projects/` (`Bybit Trading Bot.md`, `Clip Studio.md`, `Family Hub.md`, `Sproutling Isles.md`, `Trading Agent.md`, `StarNet Automation.md`) — **no note anywhere in the vault documents spreadsheet-building, Notion-template, or Google-Sheets-formula work by this team.** This is the only one of the three lines with no existing project experience or in-vault source material to draw on; a first product would start from zero domain material, unlike printables (has [[Family Hub]] concepts to draw on) or guides (has the whole Sproutling Isles build log).

### Side-by-side summary

| | Family printables | Roblox guides | Spreadsheet/Notion templates |
| --- | --- | --- | --- |
| Demand signal strength | Strong but generic (aggregator claims, unverified) | Strong for free content; thin, low-quality paid comps found | Strong but top-heavy/survivorship-biased (unverified) |
| Typical price | $5–$15 (bundles $20–$50) | $5–$10 (comps found) | $4–$10 (spreadsheets); $10–$97 (Notion, unverified) |
| Competition | High at generic end; niche angles less crowded | Free content is the main competitor; paid comps thin | Very high at generic end (50,000+ Etsy listings reported); the exact ideas named in section 4 are flagged as the most saturated sub-niches |
| Originality risk | Low brand-collision risk; design-skill gap unverified | Highest differentiation *available* (real build log) but highest risk of sounding generic if not grounded in it; honesty constraint (game unlaunched) | Low brand-collision risk; highest genericity risk |
| Team's existing material | [[Family Hub]] streak/reward concepts (app, not print design) | Full Sproutling Isles build log, QA review, decisions | None found in vault |

The pick itself is still **owner-pending** — see [[Decisions]] #20, which currently carries an earlier tentative recommendation (family printables) that this brief is meant to let the owner check against the evidence above, not confirm by default.

## Tasks
- [ ] **Owner:** decide which product line to start with (section 4) → [[Decisions]] #20.
- [ ] **Owner:** Gumroad account, payout method and token (section 5), after StarNet is installed.
- [x] **market-researcher:** demand brief for all 3 product ideas, prices, sources — done 2026-09-26, see "Demand brief (2026-09-26)" above. Pick itself still owner-pending.
- [ ] **product-maker:** draft product 1 and its listing.
- [ ] **qa-tester:** originality check on product 1.
- [ ] **knowledge-keeper:** add the weekly sales summary job once the first product is live.

## Sources
- Gumroad pricing (10% + 50¢ direct, 30% via Discover): https://gumroad.com/pricing
- Gumroad API product creation (recent, docs conflicting): https://github.com/antiwork/gumroad/pull/7518 and https://github.com/antiwork/gumroad/issues/4019
- StarNet's Gumroad key entry: `sidecar/servicekeys-catalog.js` in github.com/androoAGI/starnet

### Demand brief (2026-09-26) sources
All accessed 2026-09-26 via `WebSearch`; direct `WebFetch` of Etsy pages, individual `*.gumroad.com` product pages, `devforum.roblox.com`, and `accio.com` was blocked by the sandbox's egress proxy (Etsy and roblox.com are on the known-blocked host list in [[Environment Setup]]) — those figures are marked "search-summary only, unverified" above and should be treated as directional.
- Etsy category pages (search-summary only): https://www.etsy.com/market/chore_chart_printable · https://www.etsy.com/market/meal_plan_printable
- Outfy, "27 Top Selling Digital Products on Etsy in 2026": https://www.outfy.com/blog/top-selling-digital-products-on-etsy/
- Insight Agent, "Best Selling Printables on Etsy 2026": https://www.insightagent.app/trends/etsy-printables
- Backlinko, "Roblox User and Growth Stats You Need to Know in 2026" (3.5M developers, DevEx figures): https://backlinko.com/roblox-users
- DevForum beginner-scripting threads (search-summary only, devforum.roblox.com blocked): https://devforum.roblox.com/t/what-should-i-do-first-to-learn-scripting/1534049 · https://devforum.roblox.com/t/how-to-start-scripting/2524529
- Gumroad Roblox-guide comps (search-summary only, gumroad.com product pages blocked): https://digitalgoodsbyinga.gumroad.com/l/hgezu ($5) · https://codersstop.gumroad.com/l/roblox ($10)
- Class Central, "8 Best Roblox Scripting Courses for 2026": https://www.classcentral.com/report/best-roblox-scripting-courses/
- Medium, "14 Best Digital Products to Sell on Gumroad in 2026" (Writing & Publishing category revenue-per-product claim): https://medium.com/write-your-world/14-best-digital-products-to-sell-on-gumroad-in-2026-eda7b5b75e0b
- BizToolkit, "Notion Template Creator Earnings in 2026": https://www.biztoolkit.co/post/how-much-do-notion-template-creators-make-in-2026
- Roqstar, "Can You Still Make Money with Notion Templates in 2026?": https://roqstar.io/blog/can-you-still-make-money-with-notion-templates-in-2026
- Kupkaike, "Best-Selling Notion Templates on Etsy & Gumroad in 2026": https://kupkaike.com/blog/best-selling-notion-templates-etsy-gumroad-2026
- Kupkaike, "Is Selling Notion Templates Still Profitable in 2026?": https://kupkaike.com/blog/is-selling-notion-templates-still-profitable-2026
- Gumroad budget-spreadsheet comps (search-summary only, product pages blocked): https://marchborns.gumroad.com/l/monthlybudget ($3.99) · https://aitbahadi.gumroad.com/l/googlesheet ($6.99+, sold as PLR)
- Team's own project notes checked for spreadsheet/Notion experience (none found): `vault/Projects/Bybit Trading Bot.md`, `Clip Studio.md`, `Family Hub.md`, `Sproutling Isles.md`, `Trading Agent.md`, `StarNet Automation.md`
