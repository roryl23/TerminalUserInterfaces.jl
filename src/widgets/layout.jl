@kwdef struct Layout
  widgets::Vector
  constraints::Vector{<:Constraint}
  orientation::Symbol = :vertical
  last_area::Base.RefValue{Union{Nothing,Rect}} = Ref{Union{Nothing,Rect}}(nothing)
end

function render(layout::Layout, area::Rect, buf::Buffer)
  if length(layout.widgets) != length(layout.constraints)
    throw(ArgumentError("Number of widgets must match the number of constraints"))
  end
  layout.last_area[] = area
  orientation = layout.orientation

  rects = if orientation == :vertical
    split(Vertical(; constraints = layout.constraints), area)
  else
    split(Horizontal(; constraints = layout.constraints), area)
  end

  for (i, (widget, rect)) in enumerate(zip(layout.widgets, rects))
    render(widget, rect, buf)
  end
end

function handle_event!(layout::Layout, evt)
  isnothing(layout.last_area[]) && return false
  handle_event!(layout, evt, layout.last_area[])
end

function handle_event!(layout::Layout, evt, area::Rect)
  if length(layout.widgets) != length(layout.constraints)
    throw(ArgumentError("Number of widgets must match the number of constraints"))
  end

  rects = if layout.orientation == :vertical
    split(Vertical(; constraints = layout.constraints), area)
  else
    split(Horizontal(; constraints = layout.constraints), area)
  end

  handled = false
  for (widget, rect) in zip(layout.widgets, rects)
    handled |= handle_event!(widget, evt, rect)
  end
  return handled
end
