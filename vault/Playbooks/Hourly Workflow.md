---
tags: [playbook, automation]
updated: 2026-09-26
---
# Hourly Workflow (the standing rule)

Every hour a fresh Claude Code session (a cloud Routine) runs this playbook. At about **7:45 am Eastern** a second
Routine sends the owner a morning summary. The owner approved this on 2026-09-26 ("every hour, 24/7").
This replaces the old 20-minute loop from session `session_01HkUDBZ…` (23–25 Sep), whose queue lived in a temporary
file and is gone. The queue now lives in the vault: [[Work Queue]].

## Each hourly run (one task, then stop)
1. **Load:** `git pull` on `main`. Read `CLAUDE.md`, [[Active Context]], this playbook and [[Work Queue]].
2. **CI first:** if a project branch you or an earlier run pushed has failing CI, fixing it is this run's task.
3. **Pick ONE task:** the top unchecked item in [[Work Queue]] that is **not blocked on the owner**. Skip items marked `(owner)`.
4. **Nothing to do?** If every item is blocked, write one line in [[Work Queue]]'s run log and **stop** (keep it under 2 minutes).
5. **Do it** with the right agent from [[Team Roster]] (`.claude/agents/`). Work on that project's branch (see `CLAUDE.md`).
   Keep it to about 30 minutes, and leave the branch green: run the project's tests or lint before every push.
6. **Verify** the result yourself (read the diff, run the tests). Label anything unverified.
7. **Record:** tick the item, add follow-up items (with an owner role), add a line to the run log in [[Work Queue]],
   and a short entry at the top of [[Session Log]]. Update the project note's Tasks.
8. **Push:** the project branch, then the vault to `main` (`git pull --rebase` first; retry once on conflict).

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
1. Writes [[Morning Summary]] (newest at the top): **Done overnight** · **New projects waiting for your OK** · **Needs you** (decisions, blocked items) · **Next up**.
2. Sends one short push notification (under 200 characters) that points to the summary.
3. Pushes to `main`.
