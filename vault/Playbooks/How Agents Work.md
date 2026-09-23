---
tags: [playbook, agents]
---
# How Agents Work

The protocol that lets agents work on their own without losing context.

## 1. Memory is files, not chat
Claude doesn't remember past chats on its own. **The vault is the memory.** Anything the next session
needs goes into a vault note and gets pushed to GitHub. If it isn't in the vault, assume it's lost.

| Kind of memory | Where it goes |
| --- | --- |
| What's happening now | [[Active Context]] (rewrite; don't append) |
| What happened | [[Session Log]] (append, newest first) |
| What was decided | [[Decisions]] |
| Who the owner is and how they work | [[Owner Profile]] |
| Project knowledge, status and tasks | `vault/Projects/<Project>.md` |
| How to do something repeatable | `vault/Playbooks/` |

## 2. The orchestrator loop (main session)
1. Load context: `CLAUDE.md` → [[00 Home]] → [[Active Context]] → the project note.
2. Break the request into tasks. Pick an agent per task from [[Team Roster]].
3. Brief each agent precisely: the goal, which vault notes and files to read, what "done" means, and where to write results.
4. Run independent agents in parallel; run dependent ones in order (spec → build → review).
5. Check every result. Don't pass on claims you haven't checked.
6. Close out: session log, tasks, decisions, active context, then commit and push.

## 3. Rules every agent follows
- Read before acting. Start with the notes named in your brief, plus your row in [[Team Roster]].
- Stay in your lane. Ask the orchestrator (or leave a task for another role) instead of doing another role's job.
- Leave a trail. End with a short report: what changed, what's verified, what isn't, and new tasks with owners.
- Only real facts. Numbers need a source and an as-of date; untested code gets labelled untested.
- The owner decides direction, money, publishing and anything risky. Put those under "Waiting on the owner" in [[Active Context]].

## 4. Running agents without the owner present
- **Scheduled Routines** (Claude Code on the web) can start a fresh session on a schedule, for example a weekly trend refresh or a nightly `qa-tester` lint run. The prompt should say: "Follow `CLAUDE.md`; you are `<agent>`; do `<task>`; update the vault; push to `<branch>`."
- **Pull requests** are the safe way for agents to propose changes; the owner merges.
- Keep autonomous jobs to reversible work (research, specs, code on a branch). Publishing, spending and live trading always wait for the owner.
