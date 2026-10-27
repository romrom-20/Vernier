# Contributing to Vernier

Vernier is an early native macOS project. Start with the [product thesis](Docs/PRODUCT.md), [measurement framework](Docs/RESEARCH.md), [architecture](Docs/ARCHITECTURE.md) and [coverage contract](Docs/CONNECTOR_COVERAGE.md).

## Run locally

Use macOS with Swift 6+ and Apple Command Line Tools or Xcode. There are no third-party package dependencies; SQLite comes from the system.

```sh
./Scripts/showcase.sh
./Scripts/verify.sh
# With a logged-in graphical Mac session:
./Scripts/verify.sh --ui
```

Showcase and native smoke mode use isolated preferences, synthetic data and no personal store. Quit a normal Vernier instance before native UI testing to avoid same-bundle window interference. Restore your ordinary installed app afterward if desired. Do not enable a real connector just to reproduce a UI bug.

## Changes we can assess

Keep each change focused. Explain the user-visible trigger, the resulting behavior, and how you checked it. For a native interaction fix, include the relevant synthetic regression and the manual steps you tried. Do not mark manual checks as passed just because the state-machine test passed.

Preserve the nonactivating pill, reduced-motion behavior, clear capture feedback, explicit unknowns and source-specific consent. A connector must document supported versions, read-only methods, scope, normalization, failures and what it excludes. Never start/control an agent as a side effect of observing history.

## Privacy in contributions

Use invented prompts, paths and outcomes. Do not attach conversation exports, provider databases, private projects, credentials, local account paths, or screenshots showing personal sessions. Inspect logs and images before posting. Report security vulnerabilities through the [security process](SECURITY.md), not a public issue with a payload.

Run `python3 Scripts/test-public-content.py` and `python3 Scripts/check-public-content.py` before publication. Public images must use isolated synthetic records, be visually reviewed, and match `.github/public-images.json`. A new or changed image fails the check until its exact hash and reviewed provenance are recorded. Do not automatically approve an image because its filename says “showcase.” Never copy a screenshot of a personal session into documentation. See [publication boundaries](Docs/PUBLICATION.md).

## Evidence and product claims

Do not equate a short prompt with disengagement, time with attention, a file-open with understanding, or an agent's completion with verified success. Proposed insights need source evidence, visible uncertainty and a correction path. Use MIT-compatible original contributions; respect the source and licensing of any new assets.

## Measurement boundaries

Classify a proposal as passive observation, an active probe or a longitudinal experiment. Do not promote a transcript feature to a capability measure, or a predictive association to a causal effect. Separate what the person could do before, what AI enabled during the task, what they could do afterward unaided and what an intervention changed.

Future probes/studies need separate consent, conditions, provenance and evaluation criteria. More verification language may reflect wording or better AI output; compare the actual independent outcome. A primary-source citation is required for empirical research claims; a broad publisher link or design essay does not establish a study’s result. Negative and inconclusive findings should constrain product claims.

## Pull requests

Run `./Scripts/verify.sh` and `git diff --check`. Full Xcode also runs the shared checks through XCTest. Run native UI checks for pill/window changes on an interactive Mac. State OS/toolchain and untested behavior. CI builds and tests; it cannot certify real hardware sleep, mouse use, accessibility or cognition.
