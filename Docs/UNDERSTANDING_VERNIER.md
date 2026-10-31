# Understand Vernier as we build it

We use [Floorplan](https://github.com/haydenschmitty/floorplan) to keep a plain-language, interactive map of the actual app. The map is generated locally in `floorplan/` and stays out of git. This trial is scoped to Vernier; no global agent instruction is installed. Its skill is kept locally in `.agents/skills/floorplan`, outside version control. The agent workflow lives in [AGENTS.md](../AGENTS.md).

Start with the map's **Start here** tour. It explains how saved Codex conversations reach the private archive, how recorded replies become a daily recap, and where optional local AI offers an interpretation. The **Flows** view walks through a particular path. **Recent work** explains what changed for the owner's request, rather than listing filenames alone.

Before a substantial change, we explain the path it touches and the choice that matters. Afterward, we update the map and connect the changed parts to the reason for the change. One optional check helps you decide whether you could explain or verify it yourself. You remain free to delegate; opening a map is not a comprehension test.

## First map and later updates

Install the Floorplan skill or plugin from its upstream repository, then ask the agent to **make a floorplan of Vernier**. Later, say **update the floorplan** or use `$floorplan` in a compatible Codex session. The skill's scripts scan the source, build the map and open its local address. A new skill installation becomes available on the next turn.

The map's names and explanations are editable in `floorplan/architecture.json` and `floorplan/descriptions/`. The generated graph and page are rebuilt from those inputs. Reopening after a restart may require asking the agent to open the floorplan again.

## Three things to understand first

1. **Where the evidence comes from.** Vernier reads saved Codex history from Conductor with separate content consent. It does not watch your brain, global mouse activity or every AI tool.
2. **What a daily number means.** It describes saved follow-up wording. It cannot establish a percentage of tasks delegated or minutes spent thinking.
3. **What the local model contributes.** A conversation reading proposes a likely goal and useful check, then checks its sources. It can be wrong, and a literal boundary question has different provenance from model inference.

Useful questions to ask the map include: “Why does the compact view show yesterday?”, “What stops when I press Pause?”, and “What evidence would be needed before claiming that I understood a change?”

## Coverage and privacy

Floorplan's automatic Swift analysis is limited. The first Vernier scan found files but no file-to-file import links. Important connections are therefore added from source inspection; they are not claimed to be mechanically proven or complete. Its automatic health checks also do not replace a native-app security review.

Only repository source and invented fixtures belong in this map. Private `.context` files, conversation archives, personal notes, credentials and exports are excluded. The map and its server run locally. If you use its Ask bar, the chosen coding assistant can read project source and send it through your existing assistant account; that is distinct from local map rendering. Do not put personal sessions into questions, enable a new provider without consent, or publish the map without reviewing it.
