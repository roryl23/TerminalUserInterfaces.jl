
const ResizeEvent = Crossterm.Event{Crossterm.ResizeEvent}
const KeyEvent = Crossterm.Event{Crossterm.KeyEvent}
const MouseEvent = Crossterm.Event{Crossterm.MouseEvent}
keycode(evt::KeyEvent) = evt.data.code
keycode(_) = ""

keymodifier(evt::KeyEvent) = evt.data.modifiers

keypress(evt::KeyEvent) = evt.data.kind == "Press" ? keycode(evt) : ""
keypress(_) = ""

mousekind(evt::MouseEvent) = evt.data.kind
mousekind(_) = ""

# Crossterm reports zero-based mouse positions. The TUI layout and buffer APIs are one-based.
mousecolumn(evt::MouseEvent) = evt.data.column + 1
mouserow(evt::MouseEvent) = evt.data.row + 1
mouseposition(evt::MouseEvent) = (mousecolumn(evt), mouserow(evt))
mouseposition(_) = (0, 0)

function mousewheel(evt::MouseEvent)
  kind = lowercase(mousekind(evt))
  occursin("scrollup", kind) && return 1
  occursin("scrolldown", kind) && return -1
  return 0
end
mousewheel(_) = 0
