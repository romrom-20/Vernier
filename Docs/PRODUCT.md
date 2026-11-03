# Understanding human agency in AI-mediated work

## The central question

> As I use AI, am I choosing the direction—or is the interaction carrying me toward choices I did not intend? How is my relationship with AI changing over time?

Vernier is a human-first personal instrument for investigating that question. Coding work is the first observable setting, not the product's boundary. The ambition includes personal agents, research, planning and everyday decisions where a connected source exposes usable evidence with consent. Today only the Codex-in-Conductor path is connected; this ambition does not imply capture from other apps.

Finishing work is one outcome. Retaining judgment, recognizing influence, choosing delegation deliberately and being able to revisit a decision are separate concerns. Accepting advice can be excellent judgment. A change of mind is not automatically an unwanted loss of direction, and a missing reason in a chat is not proof that the person had none.

## The intended everyday experience

Vernier should collect quietly and offer occasional useful reflections, rather than make the person continually watch a dashboard. A useful reading would connect a concrete decision to the person's stated priorities, what the AI introduced, how the person responded, and any later report about the outcome. It would invite correction when intentionality is unknown.

For an invented example: a person wanted a private local journal; an agent recommended a hosted service; the person approved the proposal. The observable change is local → hosted. Vernier can ask whether the privacy priority changed deliberately. It cannot decide from a short approval that the person surrendered judgment. If they say the change was unintended, that is a human report tied to this decision, separately from the original observation.

The proposed longitudinal view should help answer:

- **Whose priorities shaped the decision?** Compare the person's stated aim and boundaries with the recommendation and later choice.
- **Was the change deliberate?** Retain explicit reasons or the person's later correction; otherwise show that intention is unknown.
- **What followed from the choice?** Connect available outcomes and later satisfaction, regret or a changed preference without assuming every outcome was caused by AI.
- **What remains within my judgment?** Separately consented attempts could test explaining, challenging or recovering a narrow decision; asking for an explanation does not demonstrate the capability.

This decision history and a personal baseline are proposed, not implemented by the current daily recap. Descriptive changes in a person's records, independent capability and a causal claim about what AI did to them need different evidence. Changes could also reflect task mix, prior skill, available time and deliberate preferences.

The everyday feedback should say **what changed, why it may matter to this person, what remains uncertain, and one useful way to check**. It should not turn model agreement, prompt length, message counts, clicks or a map opening into a measure of cognitive strain or agency.

## What the existing boxes actually do

The default five categories remain English wording rules. An explicit experimental switch now provides contextual model categories, retaining additional acts and marking unread/unsupported replies as unclear. The experiment is off initially because the tested configurations failed their quality gate; it is not a reliable judge of steering. Model agreement and exact citations do not prove semantic accuracy. [Category mechanics](DAILY_RECAP.md).

The separate contextual goal reader remains available with its existing review controls. Narrow boundary rules can flag an explicit requirement conflicting with a later agent proposal and brief assent. This is a source-backed question, not a validated answer to whether the person is being steered overall. There is no all-life AI-impact score or longitudinal human-judgment model today.

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

Version 0.14.0 provides a quiet circle/pill, compact recap, dashboard, read-only Codex history from Conductor, separately enabled conversation memory and local storage controls. Daily cards describe saved follow-up wording, an hourly chart opens exact replies, optional check-ins record clarity and energy, and local contextual readings suggest goals and concrete checkpoints with inspectable sources. The visual overview and contextual explanation complement each other. Model regressions still miss useful readings; the public previews use invented records and hand-authored readings.

Connected personal-agent histories, a decision ledger across domains, personal baselines and validated adaptive guidance are not implemented. The app does not predict independent capability, establish lasting change caused by AI, diagnose cognitive dysfunction or calculate an agency/strain/readiness score.

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


### Human-first presentation — 0.9.0

The first screen should help a person recognize their own contribution. One reading connects an agent reply to what the person added, questioned or returned to, with literal sources and a short account of why it may matter. Internal workspace names, inventory totals and wording bins no longer lead the experience. This is a contextual observation layer; it does not demonstrate comprehension, the amount of mental effort used, or overall independence from the agent. See [the implemented reading contract](PARTICIPATION.md).
