"""
Render Trait for widget
"""
function render(widget, area::Rect, buffer::Buffer) end

"""
Handle an input event for a widget.
"""
handle_event!(widget, evt) = false
handle_event!(widget, evt, area::Rect) = handle_event!(widget, evt)

Base.@kwdef struct Word
  text::String
  style::Crayon = Crayon()
end
