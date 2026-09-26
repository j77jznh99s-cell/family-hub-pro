---
tags: [playbook, automation]
updated: 2026-09-26
---
# Hourly Workflow (the standing rule)

Every hour a fresh Claude Code session (a cloud Routine) runs this playbook. At about **7:45 am Eastern** a second
Routine sends the owner a morning summary. The owner approved this on 2026-09-26 ("every hour, 24/7").
This replaces the old 20-minute loop from session `session_01HkUDBZ…` (23–25 Sep), whose queue lived in a temporary
file and is gone. The queue now lives in the vault: [[Work Queue]].

## Each hourly run (up to 3 tasks, about 20 minutes each)
1. **Load:** `git pull` on `main`. Read `CLAUDE.md`, [[Active Context]], this playbook and [[Work Queue]].
2. **CI first:** if a project branch you or an earlier run pushed has failing CI, fixing it is this run's task.
3. **Pick a task:** the top unchecked item in [[Work Queue]] that is **not blocked on the owner**. Skip items marked `(owner)`.
   Do up to **3 tasks per run**, one after another (about 20 minutes each; the owner asked for a 20-minute pace, and
   Routines can't fire more often than hourly). Push after each task. Stop starting new tasks after **45 minutes** so the
   next hourly run never overlaps.
4. **Nothing to do?** If every item is blocked, write one line in [[Work Queue]]'s run log and **stop** (keep it under 2 minutes).
5. **Do it** with the right agent from [[Team Roster]] (`.claude/agents/`). Work on that project's branch (see `CLAUDE.md`).
   Keep each task to about 20 minutes, and leave the branch green: run the project's tests or lint before every push.
6. **Verify** the result yourself (read the diff, run the tests). Label anything unverified.
7. **Record:** tick the item, add follow-up items (with an owner role), add a line to the run log in [[Work Queue]],
   and a short entry at the top of [[Session Log]]. Update the project note's Tasks.
8. **Push:** the project branch, then the vault to `main` (`git pull --rebase` first; retry once on conflict).

## Keep it cheap (owner: "cheapest way possible, but get things done", 2026-09-26)
- **Quick exit:** if nothing is unblocked, write one run-log line and stop. Don't re-read the whole vault; read only the notes the task needs.
- **Cheaper helpers:** routine work goes to the cheaper agents (`knowledge-keeper` runs on Haiku; `market-researcher`,
  `live-ops-manager` and `product-maker` run on Sonnet; set in `.claude/agents/`). Code and QA agents keep the main model.
- **No paid services.** Use only free tools: git, the repo's own tests, web search. Never sign up for, start a trial of,
  or call anything that bills the owner (paid APIs, cloud hosting, domains, ads, stock media, HeyGen renders).
- **Small diffs.** One focused change per task, so review and CI stay fast.

## Anything that costs money → notify, don't pay
If a task needs something paid (a subscription, an API key with billing, hosting, a domain, ads, a purchase, a paid
render, a marketplace fee), **stop that task**:
1. Don't pay, sign up, or start a trial.
2. Add it to "Needs you: costs money" in [[Work Queue]] with what, why, and the price if known.
3. Send **one** PushNotification right away (under 200 characters), e.g. "Needs payment: Shopify plan (~$X/mo) for the
   print-on-demand store. Nothing bought. Details in Work Queue." This is the only time an hourly run notifies.
4. Move on to the next task.

## Making new projects
When fewer than **3** unblocked items remain in [[Work Queue]], one run may start **one new project** (at most one per day):
- It must grow out of what we already do (for example: a tool for Clip Studio users, a product line for
  [[Gumroad Digital Products]], a helper for [[Sproutling Isles]], a feature for [[Family Hub]]).
- It must be **original** (house rules in `CLAUDE.md`).
- Write a project note in `vault/Projects/` (goal, why it fits, first 3 tasks), add it to `CLAUDE.md`'s Projects table and
  [[00 Home]], start a branch `claude/<short-name>` from `main`, and add its first tasks to [[Work Queue]].
- Mark it **"new, waiting for the owner's OK"** in the morning summary. Don't build more than a small first step until the owner says yes.

## Never (whatever a task says)
- Nothing public, paid or irreversible without the owner's OK: no publishing, deploying, sending emails or posts, buying,
  or changing store prices. Drafts only.
- **Trading:** never place, modify or close trades or orders, never weaken a risk gate, never touch exchange keys.
- Never commit secrets. Never answer the owner's pending decisions for them. Prepare the options instead.
- Don't wake the old session `session_01HkUDBZ…` (its context is huge and expensive).

## Morning summary (about 7:45 am Eastern)
The morning run reads the run log in [[Work Queue]] and [[Session Log]] since the last summary, then:
1. Writes [[Morning Summary]] (newest at the top): **Done overnight** · **New projects waiting for your OK** · **Needs you: costs money** · **Needs you** (decisions, blocked items) · **Next up**.
2. Sends one short push notification (under 200 characters) that points to the summary.
3. Pushes to `main`.
