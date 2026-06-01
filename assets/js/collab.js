// Real-time collaborative editing client.
//
// Binds a CodeMirror 6 editor to a server-authoritative Yjs document over a
// Phoenix channel (`doc:<file_id>`), using y-codemirror.next for the editor
// binding + remote cursors and y-phoenix-channel as the network provider.
//
// The shared text is the Y.Text named "content" — it must match the name the
// server seeds in Typster.Collab.FilePersistence.

import * as Y from "yjs"
import { yCollab } from "y-codemirror.next"
import { PhoenixChannelProvider } from "y-phoenix-channel"
import { Socket } from "phoenix"

// One shared Phoenix socket for all collaborative docs in this tab.
let collabSocket = null
function getSocket() {
  if (!collabSocket) {
    collabSocket = new Socket("/socket", {})
    collabSocket.connect()
  }
  return collabSocket
}

// A stable-ish per-user colour so remote cursors are distinguishable.
const CURSOR_COLORS = [
  "#6366f1", "#0ea5e9", "#10b981", "#f59e0b", "#f43f5e", "#8b5cf6", "#14b8a6"
]
function pickColor(seed) {
  let h = 0
  for (const ch of String(seed || "anon")) h = (h * 31 + ch.charCodeAt(0)) >>> 0
  return CURSOR_COLORS[h % CURSOR_COLORS.length]
}

// Creates a collaborative binding for `fileId`. Returns the CodeMirror
// extension to add to the editor plus a destroy() for teardown.
export function createCollab(fileId, user = {}) {
  const ydoc = new Y.Doc()
  const provider = new PhoenixChannelProvider(getSocket(), `doc:${fileId}`, ydoc)
  const ytext = ydoc.getText("content")

  const color = user.color || pickColor(user.name || user.id)
  provider.awareness.setLocalStateField("user", {
    name: user.name || "Anonymous",
    color,
    colorLight: color + "33"
  })

  return {
    extension: yCollab(ytext, provider.awareness),
    ytext,
    provider,
    destroy() {
      try {
        provider.destroy()
      } catch (_e) {
        /* already torn down */
      }
      ydoc.destroy()
    }
  }
}
