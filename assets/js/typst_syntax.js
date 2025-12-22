import { StreamLanguage } from "@codemirror/language"
import { HighlightStyle, syntaxHighlighting } from "@codemirror/language"
import { tags as t } from "@lezer/highlight"

const typstHighlightStyle = HighlightStyle.define([
  { tag: t.heading1, color: "#f92672", fontWeight: "bold" },
  { tag: t.heading2, color: "#a6e22e", fontWeight: "bold" },
  { tag: t.heading3, color: "#66d9ef", fontWeight: "bold" },
  { tag: t.emphasis, fontStyle: "italic", color: "#f8f8f2" },
  { tag: t.strong, fontWeight: "bold", color: "#f8f8f2" },
  { tag: t.keyword, color: "#f92672", fontWeight: "bold" },
  { tag: t.string, color: "#e6db74" },
  { tag: t.comment, color: "#75715e", fontStyle: "italic" },
  { tag: t.number, color: "#ae81ff" },
  { tag: t.operator, color: "#f8f8f2" },
  { tag: t.bracket, color: "#f8f8f2" },
  { tag: t.variableName, color: "#f8f8f2" },
  { tag: t.function(t.variableName), color: "#a6e22e" },
])

function tokenizeTypst(stream, state) {
  if (stream.sol() && stream.match(/^#set\s/)) {
    return "keyword"
  }

  if (stream.sol() && stream.match(/^#show\s/)) {
    return "keyword"
  }

  if (stream.sol() && stream.match(/^#let\s/)) {
    return "keyword"
  }

  if (stream.sol() && stream.match(/^#include\s/)) {
    return "keyword"
  }

  if (stream.sol() && stream.match(/^#import\s/)) {
    return "keyword"
  }

  if (stream.sol() && stream.match(/^=\s+/)) {
    return "heading1"
  }

  if (stream.sol() && stream.match(/^==\s+/)) {
    return "heading2"
  }

  if (stream.sol() && stream.match(/^===\s+/)) {
    return "heading3"
  }

  if (stream.match(/^\*\*/)) {
    if (stream.match(/[^*]+\*\*/)) {
      return "strong"
    }
    return "strong"
  }

  if (stream.match(/^__/)) {
    if (stream.match(/[^_]+__/)) {
      return "emphasis"
    }
    return "emphasis"
  }

  if (stream.match(/^\*/)) {
    return "strong"
  }

  if (stream.match(/^_/)) {
    return "emphasis"
  }

  if (stream.match(/^\/\/.*/)) {
    return "comment"
  }

  if (stream.match(/^```/)) {
    stream.skipToEnd()
    return "comment"
  }

  if (stream.match(/^`[^`\n]+`/)) {
    return "string"
  }

  if (stream.match(/^\$[^$\n]+\$/)) {
    return "number"
  }

  if (stream.match(/^#[a-zA-Z_][a-zA-Z0-9_]*/)) {
    return "keyword"
  }

  if (stream.match(/^[a-zA-Z_][a-zA-Z0-9_]*\(/)) {
    return "function"
  }

  if (stream.match(/^[0-9]+(\.[0-9]+)?/)) {
    return "number"
  }

  if (stream.match(/^"[^"]*"/)) {
    return "string"
  }

  if (stream.match(/^'[^']*'/)) {
    return "string"
  }

  stream.next()
  return null
}

const typstLanguage = StreamLanguage.define({
  name: "typst",
  token: tokenizeTypst,
  startState() {
    return {}
  },
  copyState(state) {
    return {}
  },
  tokenTable: {
    keyword: t.keyword,
    heading1: t.heading1,
    heading2: t.heading2,
    heading3: t.heading3,
    strong: t.strong,
    emphasis: t.emphasis,
    comment: t.comment,
    string: t.string,
    number: t.number,
    function: t.function(t.variableName),
  }
})

export function typst() {
  return [
    typstLanguage,
    syntaxHighlighting(typstHighlightStyle)
  ]
}
