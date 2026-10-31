# Explain the work with Floorplan

Use Floorplan for substantial Vernier changes so the owner can understand and steer the work.

- Start from the local `floorplan/` map when available; verify important claims against current code.
- Use the project-local `floorplan` skill in `.agents/skills/floorplan`. If it is missing, explain that and follow `Docs/UNDERSTANDING_VERNIER.md`.
- Before a substantial change, explain the relevant path through the app in plain language and the decision the owner can make.
- After changing behavior, refresh the map, review affected descriptions and flows, and record the user's goal and why each changed part matters under Recent work.
- Offer one short, optional question or hands-on check that helps the owner explain or verify the change. Do not turn every small edit into a lesson or block authorized work for a quiz.
- Distinguish existing behavior, proposed work and uncertainty. Swift connections need source verification; a missing automatically detected link is not proof that no dependency exists.
- Opening a map, writing a long prompt or giving a short approval does not prove understanding, thought or disengagement.
- Keep `floorplan/` local and out of git. Exclude `.context/`, saved conversations, personal databases, credentials, exports and local configuration from maps, examples and uploads.
- Use only source code and invented fixtures for public explanations. Do not send personal sessions to Floorplan's Ask bar or another service.
- Maps are an explanation aid; source review and appropriate tests still determine whether a change works.
