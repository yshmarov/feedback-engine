/*
 * feedback_engine widget — self-contained, no framework, no build step.
 *
 * Reads its config from the <script type="application/json"
 * data-feedback-engine-config> the server renders — re-read on every render so
 * a Turbo visit always reflects the current page's config.
 *
 * A floating button (or any host element carrying `data-feedback-engine-open`)
 * opens a small modal form: type, optional section, message, optional
 * screenshots. The form POSTs multipart form data to the mounted engine with
 * the page's CSRF token. Esc or the backdrop closes it.
 */
(function () {
  "use strict";

  var config = readConfig();
  if (!config || window.__feedbackEngineLoaded) return;
  window.__feedbackEngineLoaded = true;

  var Z = 2147483000;
  var overlay = null;
  var lastFocused = null;
  var fileInput = null;
  var fileChips = null;

  function ready(fn) {
    if (document.readyState === "loading") {
      document.addEventListener("DOMContentLoaded", fn);
    } else {
      fn();
    }
  }

  ready(function () {
    // Document-level listeners survive Turbo navigations; register them once.
    document.addEventListener("keydown", handleKeydown);
    document.addEventListener("click", handleOpenerClick, true);

    // The button lives in <body>, which Turbo replaces on every visit, so
    // re-run the per-page setup on each visit. render() also runs now for the
    // initial (or non-Turbo) load.
    render();
    document.addEventListener("turbo:load", render);
  });

  function readConfig() {
    var el = document.querySelector("script[data-feedback-engine-config]");
    if (!el) return null;
    try {
      return JSON.parse(el.textContent);
    } catch (e) {
      return null;
    }
  }

  function render() {
    // Re-read on each visit: the config block is data (not an executed
    // script), so it reflects the page Turbo just rendered.
    config = readConfig() || config;
    injectStyles();
    if (config.showButton !== false) buildButton();
  }

  function handleOpenerClick(event) {
    var opener = event.target && event.target.closest
      ? event.target.closest("[data-feedback-engine-open]")
      : null;
    if (!opener) return;
    event.preventDefault();
    event.stopPropagation();
    openForm();
  }

  function handleKeydown(event) {
    if (event.key === "Escape" && overlay) closeForm();
  }

  // --- floating button --------------------------------------------------------

  function buildButton() {
    if (document.getElementById("fbe-button")) return;
    var button = document.createElement("button");
    button.id = "fbe-button";
    button.type = "button";
    button.setAttribute("data-feedback-engine-open", "");
    button.textContent = config.buttonLabel || config.labels.button;
    document.body.appendChild(button);
  }

  // --- form -------------------------------------------------------------------

  function openForm() {
    if (overlay) return;
    lastFocused = document.activeElement;

    overlay = document.createElement("div");
    overlay.id = "fbe-overlay";
    overlay.addEventListener("mousedown", function (event) {
      if (event.target === overlay) closeForm();
    });

    var dialog = document.createElement("div");
    dialog.id = "fbe-dialog";
    dialog.setAttribute("role", "dialog");
    dialog.setAttribute("aria-modal", "true");
    dialog.setAttribute("aria-labelledby", "fbe-title");
    if (config.rtl) dialog.setAttribute("dir", "rtl");

    dialog.appendChild(header());
    dialog.appendChild(form());
    overlay.appendChild(dialog);
    document.body.appendChild(overlay);

    // Keep Tab (and Shift+Tab) cycling inside the dialog while it is open.
    overlay.addEventListener("keydown", trapFocus);

    // Screenshots can be pasted (Cmd/Ctrl+V) or dropped anywhere on the form —
    // the file picker is just one way in.
    if (config.screenshots.enabled) {
      dialog.addEventListener("paste", function (event) {
        var files = event.clipboardData && event.clipboardData.files;
        if (files && files.length) {
          event.preventDefault();
          addFiles(files);
        }
      });
      dialog.addEventListener("dragover", function (event) {
        event.preventDefault();
      });
      dialog.addEventListener("drop", function (event) {
        event.preventDefault();
        if (event.dataTransfer) addFiles(event.dataTransfer.files);
      });
    }

    var first = dialog.querySelector("select, textarea, input");
    if (first) first.focus();
  }

  function closeForm() {
    if (!overlay) return;
    overlay.remove();
    overlay = null;
    fileInput = null;
    fileChips = null;
    if (lastFocused && lastFocused.focus) lastFocused.focus();
  }

  function trapFocus(event) {
    if (event.key !== "Tab" || !overlay) return;
    var focusable = overlay.querySelectorAll("button, select, textarea, input, a[href]");
    if (!focusable.length) return;
    var first = focusable[0];
    var last = focusable[focusable.length - 1];
    if (event.shiftKey && document.activeElement === first) {
      event.preventDefault();
      last.focus();
    } else if (!event.shiftKey && document.activeElement === last) {
      event.preventDefault();
      first.focus();
    }
  }

  function header() {
    var head = document.createElement("div");
    head.className = "fbe-head";

    var title = document.createElement("h2");
    title.id = "fbe-title";
    title.textContent = config.labels.title;

    var close = document.createElement("button");
    close.type = "button";
    close.className = "fbe-x";
    close.setAttribute("aria-label", config.labels.close);
    close.textContent = "×";
    close.addEventListener("click", closeForm);

    head.appendChild(title);
    head.appendChild(close);
    return head;
  }

  function form() {
    var form = document.createElement("form");
    form.addEventListener("submit", function (event) {
      event.preventDefault();
      submit(form);
    });

    if (config.kinds.length > 1) form.appendChild(kindField());
    if (config.sections.length > 0) form.appendChild(sectionField());
    form.appendChild(messageField());
    if (config.screenshots.enabled) form.appendChild(screenshotsField());

    var error = document.createElement("p");
    error.className = "fbe-error";
    error.hidden = true;
    form.appendChild(error);

    var actions = document.createElement("div");
    actions.className = "fbe-actions";

    var cancel = document.createElement("button");
    cancel.type = "button";
    cancel.className = "fbe-secondary";
    cancel.textContent = config.labels.cancel;
    cancel.addEventListener("click", closeForm);

    var save = document.createElement("button");
    save.type = "submit";
    save.className = "fbe-primary";
    save.textContent = config.labels.submit;

    actions.appendChild(cancel);
    actions.appendChild(save);
    form.appendChild(actions);
    return form;
  }

  function field(labelText, control) {
    var wrap = document.createElement("label");
    wrap.className = "fbe-field";
    var caption = document.createElement("span");
    caption.textContent = labelText;
    wrap.appendChild(caption);
    wrap.appendChild(control);
    return wrap;
  }

  function kindField() {
    var select = document.createElement("select");
    select.name = "kind";
    config.kinds.forEach(function (kind) {
      var option = document.createElement("option");
      option.value = kind.value;
      option.textContent = kind.label;
      select.appendChild(option);
    });
    return field(config.labels.kind, select);
  }

  function sectionField() {
    var select = document.createElement("select");
    select.name = "section";
    var blank = document.createElement("option");
    blank.value = "";
    blank.textContent = config.labels.sectionAny;
    select.appendChild(blank);
    config.sections.forEach(function (section) {
      var option = document.createElement("option");
      option.value = section;
      option.textContent = section;
      select.appendChild(option);
    });
    return field(config.labels.section, select);
  }

  function messageField() {
    var textarea = document.createElement("textarea");
    textarea.name = "message";
    textarea.rows = 5;
    textarea.placeholder = config.labels.messagePlaceholder;
    return field(config.labels.message, textarea);
  }

  function screenshotsField() {
    fileInput = document.createElement("input");
    fileInput.type = "file";
    fileInput.name = "screenshots";
    fileInput.multiple = true;
    fileInput.accept = "image/*";
    fileInput.addEventListener("change", renderFileChips);
    var wrap = field(config.labels.screenshots, fileInput);
    var hint = document.createElement("span");
    hint.className = "fbe-hint";
    hint.textContent = config.labels.screenshotsHint;
    wrap.appendChild(hint);
    fileChips = document.createElement("ul");
    fileChips.className = "fbe-chips";
    wrap.appendChild(fileChips);
    return wrap;
  }

  // Merge pasted/dropped images into the file input (the single source of
  // truth for what gets uploaded), capped at the configured maximum.
  function addFiles(files) {
    if (!fileInput) return;
    var transfer = new DataTransfer();
    var current = Array.prototype.slice.call(fileInput.files);
    var incoming = Array.prototype.slice.call(files).filter(function (file) {
      return /^image\//.test(file.type);
    });
    current.concat(incoming).slice(0, config.screenshots.max).forEach(function (file) {
      transfer.items.add(file);
    });
    fileInput.files = transfer.files;
    renderFileChips();
  }

  function removeFile(index) {
    if (!fileInput) return;
    var transfer = new DataTransfer();
    Array.prototype.slice.call(fileInput.files).forEach(function (file, i) {
      if (i !== index) transfer.items.add(file);
    });
    fileInput.files = transfer.files;
    renderFileChips();
  }

  function renderFileChips() {
    if (!fileChips) return;
    fileChips.textContent = "";
    Array.prototype.slice.call(fileInput.files).forEach(function (file, index) {
      var chip = document.createElement("li");
      var name = document.createElement("span");
      name.textContent = file.name;
      var remove = document.createElement("button");
      remove.type = "button";
      remove.setAttribute("aria-label", config.labels.close + " " + file.name);
      remove.textContent = "×";
      remove.addEventListener("click", function () {
        removeFile(index);
      });
      chip.appendChild(name);
      chip.appendChild(remove);
      fileChips.appendChild(chip);
    });
  }

  // --- submit -------------------------------------------------------------------

  function submit(form) {
    var message = form.querySelector("textarea[name=message]").value.trim();
    if (!message) return showError(form, config.labels.errorBlank);

    var files = fileList(form);
    if (files.length > config.screenshots.max) {
      return showError(form, config.labels.errorTooMany);
    }
    for (var i = 0; i < files.length; i++) {
      if (files[i].size > config.screenshots.maxSize) {
        return showError(form, config.labels.errorTooLarge);
      }
    }

    var data = new FormData();
    var kindSelect = form.querySelector("select[name=kind]");
    data.append("feedback[kind]", kindSelect ? kindSelect.value : config.kinds[0].value);
    var sectionSelect = form.querySelector("select[name=section]");
    if (sectionSelect && sectionSelect.value) data.append("feedback[section]", sectionSelect.value);
    data.append("feedback[message]", message);
    data.append("feedback[page_url]", window.location.href);
    files.forEach(function (file) {
      data.append("feedback[screenshots][]", file);
    });

    var save = form.querySelector(".fbe-primary");
    save.disabled = true;

    fetch(config.endpoint, {
      method: "POST",
      headers: csrfHeaders(),
      body: data,
      credentials: "same-origin"
    })
      .then(function (response) {
        if (response.ok) return thanks();
        return response
          .json()
          .catch(function () { return {}; })
          .then(function (body) {
            var messages = body && body.errors;
            showError(form, (messages && messages[0]) || config.labels.errorSave);
          });
      })
      .catch(function () {
        showError(form, config.labels.errorSave);
      })
      .finally(function () {
        save.disabled = false;
      });
  }

  function fileList(form) {
    var input = form.querySelector("input[type=file]");
    return input ? Array.prototype.slice.call(input.files) : [];
  }

  function csrfHeaders() {
    var meta = document.querySelector('meta[name="csrf-token"]');
    return meta ? { "X-CSRF-Token": meta.content } : {};
  }

  function showError(form, text) {
    var error = form.querySelector(".fbe-error");
    error.textContent = text;
    error.hidden = false;
  }

  function thanks() {
    if (!overlay) return;
    var dialog = overlay.querySelector("#fbe-dialog");
    dialog.textContent = "";
    var note = document.createElement("p");
    note.className = "fbe-thanks";
    note.textContent = config.labels.thanks;
    dialog.appendChild(note);
    setTimeout(closeForm, 1600);
  }

  // --- styles -------------------------------------------------------------------

  function injectStyles() {
    if (document.getElementById("fbe-styles")) return;
    var css = [
      "#fbe-button{position:fixed;bottom:16px;right:16px;z-index:" + Z + ";",
      "padding:10px 16px;border:0;border-radius:999px;cursor:pointer;",
      "background:#2563eb;color:#fff;font:600 14px/1 system-ui,-apple-system,sans-serif;",
      "box-shadow:0 4px 14px rgba(0,0,0,.25)}",
      "#fbe-button:hover{background:#1d4ed8}",
      "#fbe-overlay{position:fixed;inset:0;z-index:" + (Z + 1) + ";background:rgba(0,0,0,.45);",
      "display:flex;align-items:center;justify-content:center;padding:16px}",
      "#fbe-dialog{width:100%;max-width:420px;max-height:90vh;overflow:auto;",
      "background:#fff;color:#1c2024;border-radius:14px;padding:20px;",
      "font:14px/1.5 system-ui,-apple-system,sans-serif;box-shadow:0 20px 60px rgba(0,0,0,.35)}",
      "#fbe-dialog .fbe-head{display:flex;align-items:center;justify-content:space-between;margin:0 0 12px}",
      "#fbe-dialog h2{margin:0;font-size:17px}",
      "#fbe-dialog .fbe-x{border:0;background:none;font-size:22px;line-height:1;cursor:pointer;color:inherit;padding:2px 6px}",
      "#fbe-dialog .fbe-field{display:block;margin-bottom:12px}",
      "#fbe-dialog .fbe-field>span{display:block;margin-bottom:4px;font-weight:600}",
      "#fbe-dialog select,#fbe-dialog textarea,#fbe-dialog input[type=file]{width:100%;box-sizing:border-box;",
      "padding:8px;border:1px solid #d1d5db;border-radius:8px;background:inherit;color:inherit;font:inherit}",
      "#fbe-dialog input[type=file]{padding:6px;color:#6b7280;font-size:13px}",
      "#fbe-dialog input[type=file]::file-selector-button{margin-inline-end:10px;padding:6px 12px;",
      "border:1px solid #d1d5db;border-radius:6px;background:none;color:#1c2024;font:inherit;cursor:pointer}",
      "#fbe-dialog textarea{resize:vertical}",
      "#fbe-dialog .fbe-hint{display:block;margin-top:4px;font-size:12px;color:#6b7280;font-weight:400}",
      "#fbe-dialog .fbe-chips{list-style:none;margin:6px 0 0;padding:0;display:flex;flex-wrap:wrap;gap:6px}",
      "#fbe-dialog .fbe-chips li{display:flex;align-items:center;gap:4px;max-width:100%;",
      "padding:2px 4px 2px 10px;border:1px solid #d1d5db;border-radius:999px;font-size:12px;font-weight:400}",
      "#fbe-dialog .fbe-chips span{overflow:hidden;text-overflow:ellipsis;white-space:nowrap;max-width:180px}",
      "#fbe-dialog .fbe-chips button{border:0;background:none;color:inherit;cursor:pointer;",
      "font-size:14px;line-height:1;padding:2px 6px}",
      "#fbe-dialog .fbe-error{color:#dc2626;margin:0 0 12px}",
      "#fbe-dialog .fbe-actions{display:flex;justify-content:flex-end;gap:8px}",
      "#fbe-dialog button{padding:8px 14px;border-radius:8px;cursor:pointer;font:inherit}",
      "#fbe-dialog .fbe-secondary{border:1px solid #d1d5db;background:none;color:inherit}",
      "#fbe-dialog .fbe-primary{border:0;background:#2563eb;color:#fff;font-weight:600}",
      "#fbe-dialog .fbe-primary:disabled{opacity:.6;cursor:default}",
      "#fbe-dialog .fbe-thanks{margin:8px 0;text-align:center;font-size:15px}",
      "@media (prefers-color-scheme:dark){",
      "#fbe-dialog{background:#1a1f26;color:#e6e8ea}",
      "#fbe-dialog select,#fbe-dialog textarea,#fbe-dialog input[type=file]{border-color:#2a313a}",
      "#fbe-dialog input[type=file]{color:#9aa2ab}",
      "#fbe-dialog input[type=file]::file-selector-button{border-color:#2a313a;color:#e6e8ea}",
      "#fbe-dialog .fbe-chips li{border-color:#2a313a}",
      "#fbe-dialog .fbe-secondary{border-color:#2a313a}",
      "#fbe-dialog .fbe-hint{color:#9aa2ab}",
      "}"
    ].join("");
    var style = document.createElement("style");
    style.id = "fbe-styles";
    style.textContent = css;
    document.head.appendChild(style);
  }
})();
