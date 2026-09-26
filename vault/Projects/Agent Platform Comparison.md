---
tags: [research, automation]
updated: 2026-09-26
---
# Agent Platform Comparison

Owner asked (2026-09-26): are there platforms like [[StarNet Automation]] that do everything we do, or better?
Web-researched 2026-09-26; prices are from the sources below and should be re-checked before paying for anything.

## What we already have (baseline)
Claude Code on the web + hourly Routine + agent team (`.claude/agents/`) + this vault. It already covers most of
what StarNet does: an agent team, memory, scheduled work, a morning summary and push notifications. Advantages over
StarNet: runs in the cloud (no laptop left on), works fully from the phone, and runs on the Claude subscription
instead of a separate pay-as-you-go API budget. What StarNet adds: the pixel-art station and chatting through Telegram or Discord.

## Alternatives
| Platform | Good at | Catch |
| --- | --- | --- |
| n8n | Connecting apps (Gumroad, email, sheets) with AI steps | Technical setup. Self-hosted is free; cloud is about $20/mo |
| Lindy | No-code "AI employees" for email and admin | About $49/mo and up; weak for code or games |
| Relevance AI | Research and sales agents | Credits: the $199/mo plan (10k credits) can run out in about 10 days |
| Manus / Perplexity Computer | Hand off one big task and get a result back | One task at a time, not an ongoing team |
| OpenClaw | Like StarNet: local agent you text from Telegram or WhatsApp | Free (MIT), but serious security problems: anyone who gets into your chat account controls the computer |
| CrewAI / LangGraph | Building your own agent team in code | You'd be building a platform, not the projects |

## Recommendation (Claude, pending the owner's OK)
Put StarNet on hold and keep the current setup. If one extra tool is wanted later, add self-hosted **n8n** for
Gumroad sales and alerts. None of these would build the Roblox game or the apps better than Claude Code.
Tracked as [[Decisions]] #21.

## Sources
- https://www.make.com/en/blog/best-ai-agent-platforms
- https://www.datacamp.com/blog/best-ai-agents
- https://www.lindy.ai/blog/n8n-ai-agents
- https://www.lindy.ai/blog/relevance-ai-pricing
- https://contabo.com/blog/what-is-openclaw-self-hosted-ai-agent-guide/
- https://hivesecurity.gitlab.io/blog/openclaw-ai-agent-security-crisis-2026/
- https://en.wikipedia.org/wiki/OpenClaw
