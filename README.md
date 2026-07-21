# feedback_engine

[![Gem Version](https://img.shields.io/gem/v/feedback_engine)](https://rubygems.org/gems/feedback_engine)
[![CI](https://github.com/yshmarov/feedback-engine/actions/workflows/ci.yml/badge.svg)](https://github.com/yshmarov/feedback-engine/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue)](MIT-LICENSE)

In-app product feedback collection for Rails.

`feedback_engine` adds a **"Send feedback"** widget to your app — bug reports,
feature requests, general comments, with optional screenshots — and stores
every submission in your own database. A minimal built-in dashboard lets you
browse and triage what users send. No third-party service, no data leaves your
app.

- **Zero UI dependencies.** The widget is plain JavaScript and styles itself.
  No Tailwind, no Stimulus, no importmap, no build step. The dashboard renders
  its own styles too.
- **One line in your layout.** `<%= feedback_engine_tag %>` and you're
  collecting feedback.
- **Trigger it your way.** Use the built-in floating button, or hide it and
  open the form from any element with a `data-feedback-engine-open` attribute.
- **Screenshots included.** Users can attach up to 3 images (via Active
  Storage) — limits are configurable and enforced server-side.
- **Pluggable gating and attribution.** You decide who can send feedback, who
  can read it, and how a submission is attributed to a user.
- **Localized.** The widget follows your app's `I18n.locale`; translations ship
  for English plus 25 more languages — Arabic, Bengali, Bulgarian, Chinese
  (Simplified), Croatian, Dutch, French, German, Greek, Hindi, Indonesian,
  Italian, Japanese, Korean, Luxembourgish, Polish, Portuguese, Romanian,
  Russian, Spanish, Thai, Turkish, Ukrainian, Urdu and Vietnamese — with
  English fallbacks for everything else. RTL locales render mirrored.

## How it works

1. `feedback_engine_tag` renders a floating **Feedback** button (bottom-right).
2. Clicking it opens a small self-styled modal: type (bug / feature / other),
   an optional section select, a message, and optional screenshots.
3. The form `POST`s to the mounted engine with the page URL, the user agent,
   and (if you configure it) the current user — stored in the
   `feedback_engine_feedbacks` table.
4. You browse and triage submissions at the mount path (`/feedback`): status
   tabs (open → in review → resolved), type filter, screenshots inline.

## Requirements

- Ruby >= 3.2
- Rails >= 7.1
- Active Storage (only if you want screenshot uploads)

## Installation

```ruby
# Gemfile
gem "feedback_engine"
```

```bash
bundle install
bin/rails generate feedback_engine:install
bin/rails db:migrate
```

The generator:

- writes `config/initializers/feedback_engine.rb`,
- creates the `feedback_engine_feedbacks` migration,
- mounts the engine in `config/routes.rb`:

  ```ruby
  mount FeedbackEngine::Engine => "/feedback"
  ```

Then add the widget to your layout, right before `</body>`:

```erb
<%= feedback_engine_tag %>
```

> The widget reads the CSRF token from `<meta name="csrf-token">`, which
> `csrf_meta_tags` in your layout already provides in a standard Rails app.

Boot the app and look for the **Feedback** button in the bottom-right corner.
Submissions appear at [`/feedback`](http://localhost:3000/feedback) (dashboard
access defaults to development only — see below).

## Configuration

Everything is optional; the defaults work out of the box.

```ruby
# config/initializers/feedback_engine.rb
FeedbackEngine.configure do |config|
  # Who can send feedback. Return false to hide the widget and reject
  # submissions for this request. Defaults to everyone.
  config.enabled = ->(request) { true }

  # Who can browse and triage feedback at the mount path.
  # DEFAULTS TO DEVELOPMENT ONLY — override before deploying.
  config.authorize_admin = ->(request) { request.env["warden"]&.user&.admin? }

  # Attribute feedback to a user (optional). Return an object responding to
  # #id, or nil. Receives the request.
  config.current_user = ->(request) { request.env["warden"]&.user }

  # Label stored for the author and shown in the dashboard.
  config.author_label = ->(user) { user.try(:email) }

  # Feedback types users can pick from. Labels come from I18n
  # (feedback_engine.kinds.<kind>).
  config.kinds = %w[bug feature other]

  # App areas shown as a select in the widget. Empty list hides the select.
  config.sections = ["Dashboard", "Billing", "Settings"]

  # Screenshot uploads (requires Active Storage).
  config.screenshots = true
  config.max_screenshots = 3
  config.max_screenshot_size = 5.megabytes

  # Show the floating feedback button. Set false and trigger the form from
  # your own UI instead (see below).
  config.show_button = true

  # Fixed button text; leave nil to use the localized default.
  config.button_label = nil

  # Keep in sync with the `mount` in config/routes.rb.
  config.mount_path = "/feedback"

  # Called with each saved feedback — notify Slack, send an email, etc.
  config.on_submit = ->(feedback) { FeedbackMailer.with(feedback:).new_feedback.deliver_later }
end
```

### Opening the form from your own UI

Prefer a nav item over the floating button? Add `data-feedback-engine-open` to
any element and (optionally) hide the button:

```ruby
config.show_button = false # optional
```

```erb
<button data-feedback-engine-open>Send feedback</button>
```

### Protecting the dashboard

The dashboard (index/show/triage) is gated by `config.authorize_admin`, which
defaults to **development only** so a fresh install can never leak feedback in
production. Grant access however your app resolves admins:

```ruby
# Devise:
config.authorize_admin = ->(request) { request.env["warden"]&.user&.admin? }

# Basic auth, feature flag, IP allowlist — anything based on the request:
config.authorize_admin = ->(request) { Flipper.enabled?(:feedback_admin) }
```

You can also wrap the mount in your own routing constraint (the lambda still
applies on top):

```ruby
authenticate :user, ->(user) { user.admin? } do
  mount FeedbackEngine::Engine => "/feedback"
end
```

### Screenshots

Uploads use Active Storage: `bin/rails active_storage:install` if you haven't
already. Limits (`max_screenshots`, `max_screenshot_size`) are enforced
server-side and shown as a hint in the widget. If Active Storage isn't loaded,
the upload control simply doesn't render and uploads are rejected.

### Notifications

`config.on_submit` runs inline after each save — keep it fast or hand off to a
job:

```ruby
config.on_submit = ->(feedback) do
  SlackNotifier.post("New #{feedback.kind}: #{feedback.message.truncate(100)}")
end
```

### Localizing the widget

Every string resolves through Rails I18n under the `feedback_engine.*` scope
and follows the current `I18n.locale`. Missing keys fall back to English. To
add a language or reword the bundled copy, define the keys in your own locale
files (yours win over the gem's):

```yaml
# config/locales/nl.yml
nl:
  feedback_engine:
    button: "Feedback"
    title: "Feedback versturen"
    kinds:
      bug: "Fout melden"
      feature: "Functie aanvragen"
      other: "Overig"
    # …see config/locales/feedback_engine.en.yml for the full key list
```

Custom kinds get their labels the same way (`feedback_engine.kinds.<kind>`),
falling back to `kind.humanize`.

### Light / dark / system appearance

Both the widget and the dashboard follow the operating-system appearance via
`prefers-color-scheme` — no configuration needed.

## Working with feedback in code

Submissions are ordinary records:

```ruby
FeedbackEngine::Feedback.where(status: "open").newest_first.each do |feedback|
  puts "[#{feedback.kind}] #{feedback.message} — #{feedback.author_label}"
end
```

Each row stores `kind`, `section`, `message`, `status` (`open`, `in_review`,
`resolved`), `page_url`, `user_agent`, and optional `author_id` /
`author_label`. Screenshots are Active Storage attachments
(`feedback.screenshots`).

## Security

- Submission and dashboard access are both gated **on the server** for every
  request; the dashboard denies everything outside development until you
  configure `authorize_admin`.
- Screenshot count, size, and content type (images only) are validated
  server-side, regardless of what the client claims.
- The widget code carries the request's Content-Security-Policy nonce (the
  same one `ActionDispatch` emits), so it runs under a nonce-based
  `script-src` policy with no configuration. The runtime config ships as a
  `<script type="application/json">` block (data, not code), so it needs no
  nonce and stays correct across Turbo visits.
- Author attribution is stored as loose fields (no foreign key into your user
  table), so the gem never couples to your user model.

## Turbo

Works with Turbo Drive out of the box. Turbo replaces `<body>` on every visit,
which would take the floating button with it, so the widget registers its
document-level listeners once and re-renders on `turbo:load`.

## Development

```bash
bin/setup        # or: bundle install
bundle exec rspec
bundle exec rubocop
```

Tests run against a dummy Rails app under `spec/dummy`.

## License

Released under the [MIT License](MIT-LICENSE).
