# Changelog

## 0.1.0 (2026-07-21)

Initial release.

- Drop-in feedback widget (`<%= feedback_engine_tag %>`): floating button +
  self-styled modal with type, optional section, message, and optional
  screenshots. Plain JavaScript, no build step, CSP-nonce aware, Turbo-safe,
  follows system light/dark appearance and the app's `I18n.locale` (RTL
  supported).
- `feedback_engine_feedbacks` table with kind, section, message, status
  (open / in_review / resolved), page URL, user agent, and loose author
  attribution.
- Screenshot uploads via Active Storage with server-side count / size /
  content-type validation (configurable limits).
- Built-in triage dashboard at the mount path: status tabs with counts, type
  filter, detail view with screenshots, status transitions, delete. Gated by
  `config.authorize_admin` (development-only by default).
- Configuration hooks: `enabled`, `authorize_admin`, `current_user`,
  `author_label`, `kinds`, `sections`, `screenshots` limits, `show_button`,
  `button_label`, `mount_path`, `on_submit`.
- `feedback_engine:install` generator (initializer, migration, mount).
- Widget translations for English plus 25 more languages (ar, bg, bn, de, el,
  es, fr, hi, hr, id, it, ja, ko, lb, nl, pl, pt, ro, ru, th, tr, uk, ur, vi,
  zh-CN), with a parity spec keeping every locale's key set and interpolation
  placeholders in sync.
