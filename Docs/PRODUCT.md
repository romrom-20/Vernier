# A WHOOP-inspired companion for AI interaction

## The problem

AI agents make producing work easier. They also make it easier to lose the history of decisions: the original goal, the alternative that was rejected, what a person questioned, and which result was actually checked. Shipping output and retaining an understanding of it are different outcomes.

Vernier's north star is **helping people get better at working with AI as agents grow more autonomous**. The WHOOP analogy describes an ambient daily companion, longitudinal feedback and personal context. The subject is how a person prompts, steers, understands and evaluates work. It is not simply an account of what the agents executed.

Across a long task, Vernier should help reconstruct who set the goal, how it evolved, where the person pushed back, which proposals they followed, and what they understood at the end. It should support efficient delegation and thoughtful learning, with the user choosing what they wanted from the session.

[Addy Osmani's cognitive-surrender essay](https://addyosmani.com/blog/cognitive-surrender/) motivates the distinction between delegating execution and relinquishing judgment. We treat the essay as a design argument, not a validated measurement model or a license to infer cognitive condition from activity logs.

## A grounded example

A builder asks an agent to implement a floating control, tries the app, notices that hovering flickers, and points out that the apparent pause button opens the dashboard instead of pausing.

The builder's prompts may be brief. Their product testing and corrections are nevertheless evidence of independent judgment. A score based on prompt length, repeated “continue,” or elapsed time could characterize this work incorrectly. Conversely, a detailed conversation would not prove a careful review.

A useful future review might connect those reports to the implementation and regression checks, then suggest preserving the interactions as acceptance criteria. It should cite the underlying evidence and allow correction.

## The current product

The implemented app keeps local Codex session history, separately consented conversation text, safe agent activity metadata and personal notes. It exposes source coverage and gives the user direct capture controls. The dashboard now puts intent, steering and understanding first. A session exposes a bounded recent prompt trail alongside full conversation access. Its user-authored review asks what the person wanted, where they challenged or redirected the model, what they can explain, and what still needs checking. Archive totals remain available as collection details.

This is infrastructure for useful reflection. The current dashboard has not demonstrated that it can identify cognitive surrender, improve understanding or reliably link sessions to shipped outcomes. Message totals and activity charts should never be presented as that evidence.

## The interaction trajectory

A useful unit is a task across time, even when it spans multiple sessions. Keep the initial user goal, agent proposals, human interventions, changes in scope, verification evidence and user reflection connected. A later instruction to “fix it” can represent a precise correction, a recurring unresolved failure, a changed requirement, or an unexamined continuation. Establish the context before interpreting it.

Potential future feedback includes where a goal drifted, which tradeoff remained unexplained, where a correction changed the outcome, and which habits helped a user steer a similar task more effectively. These are proposed capabilities, not implemented detections. Any assessment should cite its evidence, state uncertainty, accept corrections, and distinguish an efficient choice to delegate from losing the thread.

Personal trends need comparable goals and tasks, explicit user context and enough reliable evidence. Counts of prompts, mouse events or elapsed time cannot supply a validated strain/readiness measure on their own.

## What a useful review should help answer

- Which decision changed the project, and what was its original purpose?
- What did the person challenge, correct or independently verify?
- What evidence supports the result, and who supplied it?
- Which important assumptions remain unresolved?
- When did the same question reappear across sessions?

Context matters. Delegating implementation while evaluating a product can be appropriate. Learning an unfamiliar system may call for a different kind of engagement. The user chooses the goal; Vernier should not judge every delegation against a single ideal workflow.

## Evidence boundaries

Keep observed events, agent claims, user reports, and independently checked artifacts distinct. An agent's test-passed statement is a claim until tied to trustworthy execution evidence. A file-open event, if ever separately consented, would establish an opportunity to inspect rather than comprehension. Missing review evidence means unknown, not unreviewed.

The first validation milestone is small: produce a review of a few consented sessions, ask whether the user recognizes it as accurate and useful, inspect its errors, and measure whether it helps them resolve a concrete open question. More connectors and a polished score cannot substitute for that work.

## Product principles

1. Quiet by default, with occasional useful context rather than constant interruptions.
2. Local ownership, source-specific consent and simple pause/export/delete.
3. Evidence-linked observations with visible gaps and a correction path.
4. Efficient delegation is legitimate; no moral judgment from prompt style.
5. No employee surveillance, hidden monitoring, rankings or cognitive-health diagnosis.
6. No numeric agency, strain or readiness score without a defined construct and credible validation.
