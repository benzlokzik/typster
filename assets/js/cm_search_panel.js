// Custom CodeMirror 6 search/replace panel.
//
// CodeMirror's stock search panel renders raw browser buttons/checkboxes and
// its "all" / "replace all" actions aren't self-explanatory. This module supplies
// a `search({ createPanel })` extension with a compact, product-UI panel that
// makes scope obvious through a live match count ("3 of 12" / "No results") and
// clearly-labelled, tooltipped controls. All behaviour comes from the official
// @codemirror/search commands, so search semantics are unchanged.
import {
  search,
  getSearchQuery,
  setSearchQuery,
  SearchQuery,
  findNext,
  findPrevious,
  replaceNext,
  replaceAll,
  selectMatches,
  closeSearchPanel
} from "@codemirror/search"

const MATCH_CAP = 2000 // cap the count scan on pathologically large docs

function el(tag, props = {}, children = []) {
  const node = document.createElement(tag)
  for (const [key, value] of Object.entries(props)) {
    if (key === "className") node.className = value
    else if (key === "text") node.textContent = value
    else node.setAttribute(key, value)
  }
  for (const child of children) node.appendChild(child)
  return node
}

// Lucide icon placeholder — upgraded to an <svg> by window.mkIcons (createIcons).
// Names must be present in app.js's mkIconSet, otherwise the node stays empty.
function icon(name) {
  return el("i", { "data-lucide": name, "aria-hidden": "true" })
}

function iconButton(iconName, label, extraClass = "") {
  return el(
    "button",
    {
      type: "button",
      className:
        `ts-cm-search__btn ts-btn ts-btn--ghost ts-btn--icon ts-btn--sm ${extraClass}`.trim(),
      title: label,
      "aria-label": label
    },
    [icon(iconName)]
  )
}

function toggleButton(iconName, label) {
  return el(
    "button",
    {
      type: "button",
      className:
        "ts-cm-search__btn ts-cm-search__toggle ts-btn ts-btn--ghost ts-btn--icon ts-btn--sm",
      title: label,
      "aria-label": label,
      "aria-pressed": "false"
    },
    [icon(iconName)]
  )
}

function textButton(text, label, extraClass = "") {
  return el("button", {
    type: "button",
    className: `ts-cm-search__btn ts-btn ts-btn--ghost ts-btn--sm ${extraClass}`.trim(),
    title: label,
    "aria-label": label,
    text
  })
}

export function makeSearchPanel(view) {
  const dom = el("div", { className: "ts-cm-search", role: "search" })

  // ── Find row ──────────────────────────────────────────────────────────────
  const findInput = el("input", {
    type: "text",
    className: "ts-cm-search__input",
    placeholder: "Find",
    "aria-label": "Find"
  })
  const countEl = el("span", { className: "ts-cm-search__count", "aria-live": "polite" })

  const tCase = toggleButton("case-sensitive", "Match case")
  const tRegex = toggleButton("regex", "Regular expression")
  const tWord = toggleButton("whole-word", "Whole word")

  const btnPrev = iconButton("arrow-up", "Previous match (⇧⏎)")
  const btnNext = iconButton("arrow-down", "Next match (⏎)")
  const btnSelectAll = textButton("Select all", "Select all matches (multi-cursor)")
  const btnClose = iconButton("x", "Close (Esc)", "ts-cm-search__close")

  const findRow = el("div", { className: "ts-cm-search__row" }, [
    findInput,
    countEl,
    el("div", { className: "ts-cm-search__group" }, [tCase, tRegex, tWord]),
    el("div", { className: "ts-cm-search__group" }, [btnPrev, btnNext]),
    btnSelectAll,
    btnClose
  ])

  // ── Replace row ─────────────────────────────────────────────────────────--
  const replaceInput = el("input", {
    type: "text",
    className: "ts-cm-search__input",
    placeholder: "Replace",
    "aria-label": "Replace with"
  })
  const btnReplace = textButton("Replace", "Replace next match")
  const btnReplaceAll = textButton("Replace all", "Replace all matches")

  const replaceRow = el("div", { className: "ts-cm-search__row ts-cm-search__row--replace" }, [
    replaceInput,
    btnReplace,
    btnReplaceAll
  ])

  dom.appendChild(findRow)
  dom.appendChild(replaceRow)

  if (window.mkIcons) window.mkIcons(dom)

  // ── Query state ─────────────────────────────────────────────────────────--
  function setToggle(btn, on) {
    btn.setAttribute("aria-pressed", String(on))
    btn.classList.toggle("is-active", on)
  }

  function buildQuery() {
    return new SearchQuery({
      search: findInput.value,
      replace: replaceInput.value,
      caseSensitive: tCase.getAttribute("aria-pressed") === "true",
      regexp: tRegex.getAttribute("aria-pressed") === "true",
      wholeWord: tWord.getAttribute("aria-pressed") === "true"
    })
  }

  function commit() {
    const query = buildQuery()
    if (!query.eq(getSearchQuery(view.state))) {
      view.dispatch({ effects: setSearchQuery.of(query) })
    }
  }

  let debounceTimer = null
  function debouncedCommit() {
    clearTimeout(debounceTimer)
    debounceTimer = setTimeout(commit, 120)
  }

  function countMatches(query) {
    const sel = view.state.selection.main
    let total = 0
    let current = 0
    let capped = false
    const cursor = query.getCursor(view.state)
    let step = cursor.next()
    while (!step.done) {
      total++
      if (step.value.from === sel.from && step.value.to === sel.to) current = total
      if (total >= MATCH_CAP) {
        capped = true
        break
      }
      step = cursor.next()
    }
    return { total, current, capped }
  }

  function renderCount() {
    const query = getSearchQuery(view.state)
    if (!query.search) {
      countEl.textContent = ""
      dom.classList.remove("ts-cm-search--invalid")
      return
    }
    if (!query.valid) {
      countEl.textContent = "Invalid regex"
      dom.classList.add("ts-cm-search--invalid")
      return
    }
    dom.classList.remove("ts-cm-search--invalid")
    let result
    try {
      result = countMatches(query)
    } catch (_error) {
      countEl.textContent = "Invalid regex"
      dom.classList.add("ts-cm-search--invalid")
      return
    }
    const { total, current, capped } = result
    if (total === 0) countEl.textContent = "No results"
    else if (capped) countEl.textContent = `${current || "–"} of ${MATCH_CAP}+`
    else if (current) countEl.textContent = `${current} of ${total}`
    else countEl.textContent = `${total} ${total === 1 ? "match" : "matches"}`
  }

  function syncFromQuery() {
    const query = getSearchQuery(view.state)
    if (document.activeElement !== findInput) findInput.value = query.search
    if (document.activeElement !== replaceInput) replaceInput.value = query.replace
    setToggle(tCase, query.caseSensitive)
    setToggle(tRegex, query.regexp)
    setToggle(tWord, query.wholeWord)
  }

  // ── Wiring ──────────────────────────────────────────────────────────────--
  findInput.addEventListener("input", debouncedCommit)
  replaceInput.addEventListener("input", debouncedCommit)

  for (const toggle of [tCase, tRegex, tWord]) {
    toggle.addEventListener("click", () => {
      setToggle(toggle, toggle.getAttribute("aria-pressed") !== "true")
      commit()
      findInput.focus()
    })
  }

  findInput.addEventListener("keydown", (event) => {
    if (event.key === "Enter") {
      event.preventDefault()
      commit()
      if (event.shiftKey) findPrevious(view)
      else findNext(view)
    } else if (event.key === "Escape") {
      event.preventDefault()
      closeSearchPanel(view)
      view.focus()
    }
  })

  replaceInput.addEventListener("keydown", (event) => {
    if (event.key === "Enter") {
      event.preventDefault()
      commit()
      replaceNext(view)
    } else if (event.key === "Escape") {
      event.preventDefault()
      closeSearchPanel(view)
      view.focus()
    }
  })

  // Flush the debounced query before any action so a freshly-typed find/replace
  // value (or toggle) is applied — otherwise e.g. Replace-all could run against
  // a stale/empty replacement.
  function action(run) {
    return () => {
      commit()
      run()
    }
  }

  btnPrev.onclick = action(() => findPrevious(view))
  btnNext.onclick = action(() => findNext(view))
  btnSelectAll.onclick = action(() => {
    selectMatches(view)
    view.focus()
  })
  btnReplace.onclick = action(() => replaceNext(view))
  btnReplaceAll.onclick = action(() => replaceAll(view))
  btnClose.onclick = () => {
    closeSearchPanel(view)
    view.focus()
  }

  return {
    dom,
    top: true,
    mount() {
      syncFromQuery()
      renderCount()
      findInput.focus()
      findInput.select()
    },
    update(update) {
      let queryChanged = false
      for (const tr of update.transactions) {
        if (tr.effects.some((effect) => effect.is(setSearchQuery))) {
          queryChanged = true
          break
        }
      }
      if (queryChanged) syncFromQuery()
      if (queryChanged || update.docChanged || update.selectionSet) renderCount()
    },
    destroy() {
      clearTimeout(debounceTimer)
    }
  }
}

export const searchPanelExtensions = [search({ top: true, createPanel: makeSearchPanel })]
