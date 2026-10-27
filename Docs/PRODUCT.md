# Understanding human agency in AI-mediated work

## The central question

> When does delegation expand a person’s effective capabilities, and when does it leave them less able to understand, redirect or recover the work?

Vernier is an instrument for investigating that question. Its ambition extends from a quiet Mac utility to an evidence-grounded personal agency ledger, and eventually to an experimental system for understanding how people and agents work together.

The value of delegation depends on the task, the person’s goals, their prior capability and what they can do when circumstances change. Efficient delegation is legitimate. Accepting useful advice and rejecting misleading advice can both demonstrate good judgment.

## The intended everyday experience

A person doing substantial work with AI should be able to open Vernier and recover the thread: what they intended, how they delegated, what the agent proposed, where they redirected it, what evidence was offered and what remains unresolved. Over time, the intended product would connect those threads across sessions and show changes in the person's recorded interaction patterns.

A useful recap might locate recurring requirements, stretches of simple continuation, additional verification or changes of scope. It would explain those observations in context and offer a small way to regain direction. Repeated repair may reflect a persistent agent failure; extra questions may be necessary review; a long delegated stretch may be an efficient choice. The product must keep those possibilities open rather than grade prompt style.

The intended feedback has three parts: **what happened, what it might mean for this task, and what could settle the uncertainty next**. Personal baselines and task context matter more than comparing users by approval or message counts. A behavioral recap can describe a change in the record without diagnosing a change in the person.

This everyday product direction and the longer-term measurement program have different evidence requirements. Useful memory and review can be evaluated before any capability or causal claim is made. Separately consented probes could later add evidence about narrow independent performance; longitudinal experiments would be needed to assess lasting change or intervention effects.

Codex in Conductor is the first source to make dependable. The larger ambition includes other explicitly connected tools and downstream outcomes where sources expose them with consent. It does not imply access to every interaction on a Mac.

## Three measurement layers

### 1. Passive interaction signals

This layer describes supported observations: what was delegated, revised, approved, rejected, inspected or abandoned, where a source actually exposes those actions with consent. It helps reconstruct the trajectory of a task and identify evidence worth revisiting.

The current app captures only part of this layer: local Codex conversation history, allowlisted agent activity metadata and user-authored notes. It does not establish human approval, inspection, comprehension or activity across other apps. A provider’s user-side message can contain app-added context; it is not a keystroke log.

Even complete interaction logs would not establish understanding. A person who writes “ship it” may have carefully reviewed the result elsewhere. Another who requests an explanation may simply receive a longer answer. Wording affects observability as well as behavior.

### 2. Active probes — proposed

A separately consented exercise could ask someone to predict an outcome, explain a tradeoff, verify a claim, challenge a recommendation or perform a small task independently. The result would describe a particular attempt under recorded conditions.

Independent recoverability is a promising construct: could someone locate a failure, revise a design, modify an implementation, recover useful artifacts or transfer the project without relying on the original agent? Exercises should use a sandbox rather than disrupt real work or disable AI access.

Probe results need domain, task difficulty, prior familiarity, available assistance, timing and rubric context. One attempt cannot establish permanent capability change or general cognitive condition. No probes are implemented yet.

### 3. Longitudinal experiments — proposed

A controlled study could test whether a pattern of AI use or a Vernier intervention affects later independent performance. Observation alone cannot establish that an intervention caused learning or loss of capability.

The design must separate a change in the human from a change in the AI’s output. Improved assisted task performance may be valuable while leaving independent performance unchanged. The two outcomes should be reported separately. No study assignment, randomization or intervention infrastructure is implemented.

## Four distinct outcomes

1. What the person could do before interacting with AI.
2. What AI made possible during the task.
3. What the person could do afterward without AI.
4. Whether Vernier’s own intervention changed any of those outcomes.

A ledger should retain the provenance of each kind of evidence. Agent claims, observed artifacts, user reports and measured task performance must remain distinguishable.

## Appropriate delegation and recoverability

An appropriate delegation decision uses what was known at the time. A separate question is whether the person could revise or recover that decision when new evidence arrived. Approval frequency alone cannot answer either question.

For example, a builder repeatedly reports specific failures in a floating control after an agent claims completion. Brief repair prompts can represent active evaluation. Interpreting the same wording as dependence would require evidence that the interaction log does not contain.

In tasks with a defensible correctness criterion, a future study can examine accepting correct advice and rejecting incorrect advice separately. Open-ended design work may instead need contextual expert adjudication and explicit uncertainty; an answer from another model is not automatically ground truth.

## The critical experiment and its failure condition

Test whether interaction history predicts independent understanding or recovery better than a simple baseline using task difficulty, prior skill and AI-usage counts. The evaluation must use held-out outcomes and account for repeated observations of the same person or project.

If the richer signals add no practically useful predictive value, that challenges Vernier’s measurement thesis. The project may remain valuable for memory, recovery and oversight, with narrower claims. If useful prediction is established, test whether carefully targeted interventions actually improve later independent performance.

The measurement system should be able to produce an informative negative result. Attractive numbers, higher message counts and successful agent output are not substitutes for that test.

## What exists today

Version 0.7.0 provides an optional circle/pill, menu-bar quick view, Studio, read-only Codex history, separately consented conversation memory, local storage controls and user-authored interaction review. The dashboard maps up to 500 saved messages from one session into user directions and agent reply stretches, with source comparisons and visible coverage. Optional on-device AI briefs suggest the working goal, source-linked patterns and a next step from a smaller bounded excerpt. These are fallible interpretations, not validated agency assessments.

Connected task histories, cross-session recaps, personal baselines and adaptive guidance are not implemented. The screenshots show the session-review foundation using invented records and fixed interpretations. They do not demonstrate the intended longitudinal experience or establish the local model’s accuracy.

It is a foundation for observation and reflection. It does not yet predict independent capability, validate understanding, measure permanent change, run experiments or calculate an agency/strain/readiness score.

## Product principles

- Quiet presence, user ownership and source-specific consent.
- Explicit separation between observation, user report, task performance and causal evidence.
- Visible missing data, correctable attribution and evidence-linked claims.
- Support for rational delegation, learning and recovery without moral judgments from prompt style.
- Separate consent for any future probe, intervention or study; passive capture is not research enrollment.
- No employee surveillance, hidden recording, medical diagnosis or unsupported universal cognitive claims.

See the [research framework](RESEARCH.md) for proposed study designs and the [roadmap](ROADMAP.md) for implementation gates.


### Recent-work foundation — 0.8.0

The menu-bar view and dashboard now span recent Codex sessions across Conductor workspaces, using bounded, source-linked wording cues and thread navigation. Agent-last replies and provider-reported failures help choose an exchange to inspect. These are transparent observations and rules, not semantic daily recaps or evidence of missing review. Task histories, outcome-linked reasoning and personal baselines remain planned. See [what the overview can and cannot say](WORK_OVERVIEW.md).
