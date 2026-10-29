# Native interactions and mouse checks

The app observes mouse entry/exit and dragging only for its own floating control. It does not log mouse activity elsewhere on the Mac or use clicks to score comprehension.

## Intended behavior

### Floating pill

- It is optional, defaults off and never becomes the key/main window.
- At rest it is a 28×28 point circle; hover reveals a 232×48 point panel.
- A single native tracking area survives layout changes. A 200 ms exit delay is canceled by re-entry; a resize-related exit does not dismiss a panel that still contains the pointer.
- Play/pause is a separate 28-point native button. It changes capture and its own action label in place, without opening Studio or taking keyboard focus. While paused, the action is Resume.
- Clicking the body keeps the controls open; clicking it again releases that pin. Only the separate dashboard arrow opens Studio. Dragging repositions the pill after a movement threshold; returning a drag to its starting point still never counts as a click. Control-click opens the native capture/hide/quit menu.
- The pill hides during system rest, while Studio is focused, and while quick view is open. It follows ordinary desktop Spaces and excludes full-screen Spaces.

### Menu bar and Studio

Quick view has a 356-point content width and screen-aware bounded height, with pinned header/footer actions and a scrolling center. The actual AppKit window frame, including chrome, is constrained to the visible display. Pause changes its content without resizing the window.

The coordinator owns one requested surface at a time. Menu-bar quick view hides Studio without destroying its state; Open dashboard closes quick view before raising Studio. Activation/reopen events while quick view is open do not summon a second dashboard, and late popover/key-window notifications must respect the requested surface. Closing Studio leaves the status item running. Reopening restores the current page. Unminimizing is requested only for an actually minimized window; requesting it for ordinary windows can schedule a delayed show and interfere with a floating control.

## Automated native regression

Run `./Scripts/verify.sh --ui` in a logged-in graphical Mac session, with other Vernier copies quit. Tests use isolated preferences, synthetic data and no personal store.

The native host/window checks cover:

- Compact/expanded widths, host identity and four resize-like exits under a stationary injected pointer.
- Re-entry canceling dismissal, followed by an outside pointer contracting the panel.
- Hit testing returning the native capture button; button actions toggling persisted Pause in both directions while Studio remains closed.
- Nonactivation, hide/show conditions, full-screen/Spaces configuration and rest preserving Pause.
- Bounded quick-view size/frame and no resize on Pause.

These tests call native handlers/actions with a controlled own-panel pointer location. They do **not** automate a physical mouse or establish real multi-display, full-screen, sleep/wake, accessibility or long-duration performance behavior. Pure layout/policy tests also exercise a display with a negative origin.

## Manual mouse checklist

Use `./Scripts/showcase.sh` for synthetic-only reproduction. These are acceptance steps, not claims of a completed hardware test matrix. Record the OS, scale factor, display arrangement and revision with any result.

- [ ] Enter the compact pill from each edge. Hold still, then move across the text/button/chevron. No repeated collapse/expansion.
- [ ] Leave the expanded pill, quickly return, then leave fully. No flicker or stuck-open state.
- [ ] Click play/pause repeatedly. Status/action update once per click; Studio stays closed; the previously focused app keeps keyboard focus.
- [ ] Click the circle/body. Controls stay open without summoning Studio. Click the dashboard arrow; only Studio opens and the pill hides.
- [ ] Drag compact and expanded forms. Placement follows the pointer and release does not open Studio.
- [ ] Control-click both forms; use Resume/Pause, Hide and Open. Escape dismisses the menu.
- [ ] Open quick view on every attached display. Its close/footer controls remain reachable; Pause does not move it. Open dashboard from quick view, then open quick view again: the two must replace each other, including rapid repeats.
- [ ] Minimize, restore and close Studio. Presence follows focus without duplicate panels or delayed window reappearance.
- [ ] Test ordinary/full-screen Spaces, unplug a display, and change scale/arrangement. The panel remains recoverable.
- [ ] Enable Reduce Motion and test VoiceOver/keyboard access. Capture has a named action and status is not color-only.

Actual sleep/login testing uses a normal consenting installation, not showcase: preserve user Pause across rest and confirm actual OS login approval. See [validation](VALIDATION.md).


## Reasoning controls — 0.10.0

Overview selects a conversation and its latest source-backed reading. The history disclosure opens earlier accounts and can return to the latest. Read original loads the canonical source by message ID, with an explicit route to the full conversation; See the surrounding exchange opens the map at the actual anchor. Revisit honors consent, pause and unchanged-evidence reuse; Stop review invalidates the current result without stopping capture. Add my perspective opens an explicit local report editor; saving it can trigger a revised interpretation. Engine selection, the separate automatic-revisit switch and Check local engine are in the reasoning disclosure. Automatic inference starts off; collection is independent. The isolated showcase blocks model calls and saves, while demonstrating invented revision history.

## Contextual review and quiet direction cues — 0.11

The main view names the manual/automatic/paused state, offers Follow changed work and leads with a practical checkpoint. Why this appeared is collapsed; Read original uses exact canonical IDs. The circle stays static while its amber center marks a current eligible direction question; the menu-bar icon and accessibility label also carry that cue. The explicit dashboard arrow selects the question's conversation rather than unrelated latest work. No automatic expansion or keyboard-focus request is added.

That was intentional / I want to check this save source-scoped reports. Their stable pair key suppresses repeat cues across later short approvals of the same proposal, without silencing a different or edited proposal. Pause/rest/revocation, source changes, erasure and a one-hour age limit suppress ambient questions. The underlying Mac focus and physical mouse matrix still needs its normal native QA; offscreen layout renders do not substitute for it.
