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

## Tasks
- [ ] **Owner:** decide which product line to start with (section 4) → [[Decisions]] #20.
- [ ] **Owner:** Gumroad account, payout method and token (section 5), after StarNet is installed.
- [ ] **market-researcher:** demand brief for the chosen line (3 product ideas, prices, sources).
- [ ] **product-maker:** draft product 1 and its listing.
- [ ] **qa-tester:** originality check on product 1.
- [ ] **knowledge-keeper:** add the weekly sales summary job once the first product is live.

## Sources
- Gumroad pricing (10% + 50¢ direct, 30% via Discover): https://gumroad.com/pricing
- Gumroad API product creation (recent, docs conflicting): https://github.com/antiwork/gumroad/pull/7518 and https://github.com/antiwork/gumroad/issues/4019
- StarNet's Gumroad key entry: `sidecar/servicekeys-catalog.js` in github.com/androoAGI/starnet
