# A visual story of the work

The session map introduced in 0.7 remains the conversation drill-down. Version 0.8 starts with a [work overview across sessions](WORK_OVERVIEW.md), so the newest conversation does not represent all work.

The small session brief could repeat a person's request instead of explaining an interaction. The dashboard now starts with a suggested finding, an explorable conversation map and the source exchanges. Its design hypothesis is that a builder can reconstruct a concrete point of friction more easily when the record, its possible meaning and a next check stay connected.

## Overview, comparison, explanation

1. **Orient:** choose a Codex conversation. See a possible finding with its AI-review coverage, plus recorded message and follow-up counts.
2. **Explore:** the upper lane contains user-side message groups; the lower lane contains contiguous agent replies, including progress messages. Follow the reading sequence. Select a point to compare it with the previous group.
3. **Interpret:** possible repair loops have separately labeled AI markers. Interpretation cards explain the hypothesis, show literal supporting messages and let the person dismiss it. A source outside the loaded map still opens in Memory.
4. **Act:** a review suggestion asks for a concrete expected-versus-observed check. It is guidance, not evidence that the person made a mistake. The generated brief and archive inventory remain available in details.

This applies the overview-to-details approach described in [Shneiderman's visualization taxonomy](https://www.cs.umd.edu/users/ben/papers/Shneiderman1996eyes.pdf). It is a design rationale, not a claim that this particular interface has passed user research. A first useful evaluation would ask builders to find a returned requirement, explain the prior agent claim, and choose what evidence could settle it.

## What the diagram means

The map loads at most the latest 500 saved messages from one session. Counts describe that loaded window, with loaded-versus-stored coverage visible. Pure known injected-context blocks are omitted from visible messages. Provider user-side text can still contain app-added content.

Adjacent assistant messages are grouped into a reply stretch; consecutive user items are grouped only when they belong to the same provider turn. A follow-up is a user group immediately after an agent group. It does not establish a new requirement, correction, mistake, unreviewed acceptance or cognitive condition. A reply stretch can contain routine progress updates, not necessarily unattended autonomous work.

The vertical positions identify speakers. The horizontal positions identify reading order, not elapsed time. Neither curve height nor color represents attention, strain, success or comprehension. Missing source times make order approximate. Pagination exposes earlier groups in the loaded window; older archive text remains in Memory.

AI markers come from cached source-referenced brief interpretations. They have their own bounded review coverage, which can be smaller than the map's window. Citation integrity does not prove the classification or explanation is correct. Repeated checking can be appropriate verification.

## Motion and controls

The connector line reveals once, then stays still. Selecting a point briefly transitions the comparison. Reduce Motion disables these animations; Low Power Mode disables the introductory reveal. There is no perpetual animation or extra observation loop. This follows [Apple's motion guidance](https://developer.apple.com/design/human-interface-guidelines/motion).

Quick view now contains recent-work coverage, sampled go-ahead and question/direction cues, an inspectable thread and an Explore all work action. The earlier miniature sequence and raw follow-up headline were removed. Pause/resume stays pinned in its header. Studio and quick view retain exclusive routing. Opening the full story uses a larger, display-bounded native window. The pill's hover, in-place capture controls and nonactivation remain unchanged.

## Boundaries

The map is an in-memory projection of existing, consented local data. It adds no screen, mouse, browser or keyboard capture, no cloud request and no database migration. Completed projections are reused until source identity/update/count changes. Erasure clears them and invalidates pending reads. All public presentation images and the coding example are invented showcase records; no personal transcript is published.

This release does not implement daily cognitive spikes, personal baselines, independent-capability assessment or verified task outcomes. The local model can still misread context. Better layout helps inspect that reasoning; it does not validate it.
