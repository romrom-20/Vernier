# A visual story of the work

The session map introduced in 0.7 remains the source drill-down. Version 0.10 starts with a [revisable local reading](REASONING.md), its literal evidence, another possible account and the unresolved fact. The map shows the exchange rather than competing with a second set of older interpretation cards. Inventory counts stay in coverage details.

## Overview, evidence, correction

1. **Orient:** select a saved conversation and read the tentative account of its latest human request. The saved request is copied from the record, not presented as a verified task definition.
2. **Inspect:** compare literal speaker-labeled excerpts. Read original retrieves the canonical message by ID; See the surrounding exchange focuses the request in the map.
3. **Explore:** user groups occupy the upper lane and agent reply stretches the lower lane. Select a point to compare neighboring exchanges. Counts explain coverage and grouping, not human performance.
4. **Correct:** add a separately labeled perspective about that exact request, revisit changed evidence and compare revision history. A correction is a user report rather than proof of independent capability.

This uses an overview-to-details approach, as described in [Shneiderman's visualization taxonomy](https://www.cs.umd.edu/users/ben/papers/Shneiderman1996eyes.pdf). It is a design rationale rather than a completed user-research result. A useful evaluation would ask builders to find a returned requirement, explain the preceding agent claim and identify what evidence could settle it. The current model results do not establish those benefits.

## What the diagram means

The map loads at most the latest 500 saved messages from one session. Counts describe that loaded window, with loaded-versus-stored coverage visible. Pure known injected-context blocks are omitted from visible messages. Provider user-side text can still contain app-added content.

Adjacent assistant messages are grouped into a reply stretch; consecutive user items are grouped only when they belong to the same provider turn. A follow-up is a user group immediately after an agent group. It does not establish a new requirement, correction, mistake, unreviewed acceptance or cognitive condition. A reply stretch can contain routine progress updates, not necessarily unattended autonomous work.

The vertical positions identify speakers. The horizontal positions identify reading order, not elapsed time. Neither curve height nor color represents attention, strain, success or comprehension. Missing source times make order approximate. Pagination exposes earlier groups in the loaded window; older archive text remains in Memory.

A recurring-issue marker can come from the selected source-referenced decision revision. It attaches only where cited messages appear in the loaded map. Its reasoning packet can be smaller than the map window. Citation integrity does not prove the classification or explanation is correct. Repeated checking can be appropriate verification.

## Motion and controls

The connector line reveals once, then stays still. Selecting a point briefly transitions the comparison. Reduce Motion disables these animations; Low Power Mode disables the introductory reveal. There is no perpetual animation or extra observation loop. This follows [Apple's motion guidance](https://developer.apple.com/design/human-interface-guidelines/motion).

Quick view contains the selected reading, a saved-message excerpt, the unresolved fact, Read the evidence and Open dashboard actions. The statistics-first headline, go-ahead counters and opaque workspace/session labels were removed. Method and coverage live in Studio details. Pause/resume stays pinned in its header. Studio and quick view retain exclusive routing. Opening the full story uses a larger, display-bounded native window. The pill's hover, in-place capture controls and nonactivation remain unchanged.

## Boundaries

The map is an in-memory projection of existing, consented local data. It adds no screen, mouse, browser or keyboard capture, no cloud request. The 0.10 reasoning history adds its own schema v5 storage, separate from the transient map. Completed projections are reused until source identity/update/count changes. Erasure clears them and invalidates pending reads. All public presentation images and the coding example are invented showcase records; no personal transcript is published.

This release does not implement daily cognitive spikes, personal baselines, independent-capability assessment or verified task outcomes. The local model can still misread context. Better layout helps inspect that reasoning; it does not validate it.
