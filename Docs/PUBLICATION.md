# What belongs in the public repository

The repository publishes Vernier's source, tests, documentation and reviewed synthetic presentation assets. A person's captured conversations, AI briefs, notes, databases, exports, provider credentials, local settings and workspace attachments belong on their Mac.

The application does not upload those records to GitHub. Source publication is a separate development operation; it must review what Git will actually publish, including history and images.

## Boundaries enforced by checks

- `.context/`, build directories and common local database, export/log, credential and app-bundle artifacts are ignored. The tracked-content checker rejects private artifact paths even if they were force-added.
- Workstation-specific home paths, unreviewed binary files and symlinks are rejected. The checker also catches a limited private-key pattern; it is not a general secret scanner.
- Every tracked image needs an exact SHA-256 match and a provenance entry in [.github/public-images.json](../.github/public-images.json). Replacing a reviewed image with another capture fails until the new image is reviewed and the manifest deliberately updated.
- Eight isolated tests exercise accepted source, force-added private files, image changes, unlisted images, unknown binaries, personal home paths, symlinks and generic example paths. CI runs those tests and the tracked-content check.

These are publication safeguards, not a proof that every sensitive fact can be recognized automatically. Text and image review remain necessary. A deliberately changed manifest cannot substitute for checking an image's contents.

## Public-history review

The review on 27 October 2026 covered the published `main` history from the clean public root [`ac30512`](https://github.com/romrom-20/Vernier/commit/ac30512f6b54dfb9a6e160a23432d7a730bfa188) through [`02f442f`](https://github.com/romrom-20/Vernier/commit/02f442f253f2af5ae3fa23ad5b48b6d494f9995e), followed by the documentation and safeguard changes in this update.

The baseline contained seven commits. Gitleaks found no detected secrets in that published history. All six distinct historical image blobs were visually inspected: they show invented showcase records, rather than a personal archive. Their PNGs contained no text or EXIF metadata chunks. Current presentation images are additionally pinned by the manifest.

Published refs showed only `main`, with no tags, pull-request refs or releases at the time of review. Commit author addresses used GitHub's no-reply identity. Local development and workspace/checkpoint history was excluded from the public lineage. No personal database or conversation export was opened or uploaded for this audit.

This records a point-in-time review, not a guarantee about future contributions or copies outside the repository.

## Before publishing an update

1. Inspect the staged file list and diff. Keep personal artifacts and audit output outside the tracked tree.
2. Use the isolated showcase for public images. Read every visible label and message, and check the background and metadata. Record only reviewed synthetic image bytes in the manifest.
3. Run the publication tests/checker, secret scanning on the exact source snapshot, and a documentation-link check. Review the relevant published history when auditing an existing repository; deleting a file from the current tree does not remove its older versions.
4. Push only the intended source branch. Do not mirror all refs or include workspace/checkpoint branches.
5. Confirm the resulting public revision and CI. A source release is separate from a signed/notarized application distribution.

Do not attach real sessions to issues or pull requests. Use invented reproductions. See [contributing](../CONTRIBUTING.md), [privacy](PRIVACY.md) and [security reporting](../SECURITY.md).

## Reasoning source update — 29 October 2026

The 0.10 update was checked as an exact staged source export with Gitleaks, publication-policy tests, tracked-content/image hashes and documentation links. The secret scanner detected no secrets in that source snapshot. The three replacement images are visually reviewed offscreen renders of real native views with invented records and hand-authored readings; their precise provenance is in the image manifest. Private model reports, personal archive backups, attachments and installed bundles remain outside the tracked tree. This snapshot check does not re-audit unrelated refs or promise that arbitrary future content is safe.
