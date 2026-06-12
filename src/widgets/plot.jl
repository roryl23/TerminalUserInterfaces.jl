const ANSI_STYLE_SEQUENCE = r"\e\[[0-9;]*m"

mutable struct UnicodePlot
  block::Block
  plotter::Function
  args::Tuple
  kwargs::NamedTuple
  width::Union{Nothing,Int}
  height::Union{Nothing,Int}
  xlim::Union{Nothing,Tuple{Float64,Float64}}
  ylim::Union{Nothing,Tuple{Float64,Float64}}
  base_xlim::Union{Nothing,Tuple{Float64,Float64}}
  base_ylim::Union{Nothing,Tuple{Float64,Float64}}
  zoomable::Bool
  zoom_step::Float64
  max_zoom::Float64
  zoom_axes::Tuple{Vararg{Symbol}}
  last_area::Union{Nothing,Rect}
end

function UnicodePlot(
  plotter::Function,
  args...;
  block::Block = Block(; border = BorderNone),
  width = nothing,
  height = nothing,
  xlim = nothing,
  ylim = nothing,
  zoomable::Bool = true,
  zoom_step::Real = 1.25,
  max_zoom::Real = 64,
  zoom_axes = (:x, :y),
  kwargs...,
)
  zoom_step = Float64(zoom_step)
  max_zoom = Float64(max_zoom)
  zoom_step > 1 || throw(ArgumentError("zoom_step must be greater than 1"))
  max_zoom >= 1 || throw(ArgumentError("max_zoom must be greater than or equal to 1"))

  xlim = _plot_limit(xlim, "xlim")
  ylim = _plot_limit(ylim, "ylim")

  return UnicodePlot(
    block,
    plotter,
    args,
    NamedTuple(kwargs),
    _plot_dimension(width, "width"),
    _plot_dimension(height, "height"),
    xlim,
    ylim,
    xlim,
    ylim,
    zoomable,
    zoom_step,
    max_zoom,
    _plot_zoom_axes(zoom_axes),
    nothing,
  )
end

function _plot_dimension(value, name)
  isnothing(value) && return nothing
  value = Int(value)
  value >= 1 || throw(ArgumentError("$name must be greater than or equal to 1"))
  return value
end

_plot_limit(::Nothing, _) = nothing

function _plot_limit(limit, name)
  length(limit) == 2 || throw(ArgumentError("$name must contain exactly two values"))
  lo, hi = Float64(limit[1]), Float64(limit[2])
  isfinite(lo) && isfinite(hi) && lo < hi ||
    throw(ArgumentError("$name must be a finite increasing pair"))
  return (lo, hi)
end

_plot_zoom_axes(axis::Symbol) = (axis,)
_plot_zoom_axes(axes) = Tuple(Symbol(axis) for axis in axes)

function _plot_target_size(plot::UnicodePlot, area::Rect)
  target_width = plot.width === nothing ? width(area) : min(width(area), plot.width)
  target_height = plot.height === nothing ? height(area) : min(height(area), plot.height)
  return max(0, target_width), max(0, target_height)
end

function _build_unicode_plot(plot::UnicodePlot, canvas_width::Int, canvas_height::Int)
  kwargs = merge(plot.kwargs, (; width = canvas_width, height = canvas_height))
  plot.xlim !== nothing && (kwargs = merge(kwargs, (; xlim = plot.xlim)))
  plot.ylim !== nothing && (kwargs = merge(kwargs, (; ylim = plot.ylim)))
  return plot.plotter(plot.args...; kwargs...)
end

function _unicode_plot_text_lines(plot::UnicodePlots.Plot)
  text = sprint(show, MIME("text/plain"), plot)
  text = replace(chomp(text), ANSI_STYLE_SEQUENCE => "")
  isempty(text) && return String[]
  return Base.split(text, "\n"; keepempty = true)
end

function _unicode_plot_text_lines(plot::UnicodePlot, target_width::Int, target_height::Int)
  canvas_width = max(1, target_width)
  canvas_height = max(1, target_height)
  rendered_plot = _build_unicode_plot(plot, canvas_width, canvas_height)
  lines = _unicode_plot_text_lines(rendered_plot)

  for _ in 1:(target_width + target_height + 2)
    overflow_width = _text_width(lines) - target_width
    overflow_height = length(lines) - target_height
    overflow_width <= 0 && overflow_height <= 0 && break

    next_canvas_width = overflow_width > 0 ? max(1, canvas_width - overflow_width) : canvas_width
    next_canvas_height = overflow_height > 0 ? max(1, canvas_height - overflow_height) : canvas_height
    next_canvas_width == canvas_width && next_canvas_height == canvas_height && break

    canvas_width = next_canvas_width
    canvas_height = next_canvas_height
    rendered_plot = _build_unicode_plot(plot, canvas_width, canvas_height)
    lines = _unicode_plot_text_lines(rendered_plot)
  end

  _remember_plot_limits!(plot, rendered_plot)
  return _clip_lines(lines, target_width, target_height)
end

function _remember_plot_limits!(plot::UnicodePlot, rendered_plot)
  hasproperty(rendered_plot, :graphics) || return plot
  graphics = getproperty(rendered_plot, :graphics)

  origin_x = _float_property(graphics, :origin_x)
  plot_width = _float_property(graphics, :width)
  if plot.base_xlim === nothing && origin_x !== nothing && plot_width !== nothing && plot_width > 0
    plot.base_xlim = (origin_x, origin_x + plot_width)
  end

  origin_y = _float_property(graphics, :origin_y)
  plot_height = _float_property(graphics, :height)
  if plot.base_ylim === nothing && origin_y !== nothing && plot_height !== nothing && plot_height > 0
    plot.base_ylim = (origin_y, origin_y + plot_height)
  end

  return plot
end

function _float_property(value, name::Symbol)
  hasproperty(value, name) || return nothing
  number = getproperty(value, name)
  number isa Real || return nothing
  number = Float64(number)
  isfinite(number) || return nothing
  return number
end

function _text_width(lines::Vector{<:AbstractString})
  isempty(lines) && return 0
  return maximum(Unicode.textwidth(line) for line in lines)
end

function _clip_lines(lines::Vector{<:AbstractString}, max_width::Int, max_height::Int)
  (max_width <= 0 || max_height <= 0) && return String[]
  line_count = min(length(lines), max_height)
  return [_clip_line(lines[i], max_width) for i in 1:line_count]
end

function _clip_line(line::AbstractString, max_width::Int)
  max_width <= 0 && return ""
  used_width = 0
  io = IOBuffer()
  for grapheme in graphemes(line)
    grapheme_width = Unicode.textwidth(String(grapheme))
    used_width + grapheme_width > max_width && break
    print(io, grapheme)
    used_width += max(grapheme_width, 1)
  end
  return String(take!(io))
end

function _render_text_lines!(lines::Vector{<:AbstractString}, area::Rect, buf::Buffer)
  max_width = max(0, width(area))
  max_height = max(0, height(area))
  (max_width == 0 || max_height == 0) && return

  for (dy, line) in enumerate(lines)
    dy > max_height && break
    row = top(area) + dy - 1
    col = left(area)
    max_col = left(area) + max_width - 1
    for grapheme in graphemes(line)
      col > max_col && break
      isempty(grapheme) && continue
      set(buf, col, row, Base.first(grapheme))
      col += max(Unicode.textwidth(String(grapheme)), 1)
    end
  end
end

function render(plot::UnicodePlot, area::Rect, buf::Buffer)
  render(plot.block, area, buf)
  plot_area = inner(plot.block, area)
  plot.last_area = plot_area

  target_width, target_height = _plot_target_size(plot, plot_area)
  (target_width == 0 || target_height == 0) && return

  lines = _unicode_plot_text_lines(plot, target_width, target_height)
  _render_text_lines!(lines, plot_area, buf)
end

function render(plot::UnicodePlots.Plot, area::Rect, buf::Buffer)
  lines = _clip_lines(_unicode_plot_text_lines(plot), width(area), height(area))
  _render_text_lines!(lines, area, buf)
end

function handle_event!(plot::UnicodePlot, evt::MouseEvent, area::Rect)
  plot.last_area = area
  return handle_event!(plot, evt)
end

function handle_event!(plot::UnicodePlot, evt::MouseEvent)
  plot.zoomable || return false
  direction = mousewheel(evt)
  direction == 0 && return false
  plot.last_area === nothing && return false

  col, row = mouseposition(evt)
  _contains(plot.last_area, col, row) || return false
  return zoom!(plot, direction > 0 ? :in : :out; position = (col, row))
end

function zoom!(plot::UnicodePlot, direction::Symbol = :in; position = nothing)
  zoom_in = direction in (:in, :up, :zoom_in)
  zoom_out = direction in (:out, :down, :zoom_out)
  zoom_in || zoom_out || throw(ArgumentError("direction must be :in or :out"))

  x_fraction, y_fraction = _zoom_focus(plot.last_area, position)
  changed = false

  if :x in plot.zoom_axes
    next_xlim = _zoom_limit(plot.xlim, plot.base_xlim, x_fraction, zoom_in, plot.zoom_step, plot.max_zoom)
    changed |= next_xlim != plot.xlim
    plot.xlim = next_xlim
  end

  if :y in plot.zoom_axes
    next_ylim = _zoom_limit(plot.ylim, plot.base_ylim, y_fraction, zoom_in, plot.zoom_step, plot.max_zoom)
    changed |= next_ylim != plot.ylim
    plot.ylim = next_ylim
  end

  return changed
end

function reset_zoom!(plot::UnicodePlot)
  plot.xlim = plot.base_xlim
  plot.ylim = plot.base_ylim
  return plot
end

function _zoom_limit(current, base, fraction::Float64, zoom_in::Bool, zoom_step::Float64, max_zoom::Float64)
  limit = current === nothing ? base : current
  limit === nothing && return current

  lo, hi = limit
  span = hi - lo
  span > 0 || return current

  base_span = base === nothing ? span : base[2] - base[1]
  base_span > 0 || return current

  next_span = zoom_in ? span / zoom_step : span * zoom_step
  next_span = clamp(next_span, base_span / max_zoom, base_span)

  fraction = clamp(fraction, 0.0, 1.0)
  focus = lo + fraction * span
  next_lo = focus - fraction * next_span
  next_hi = next_lo + next_span

  if base !== nothing
    base_lo, base_hi = base
    if next_lo < base_lo
      next_lo = base_lo
      next_hi = next_lo + next_span
    end
    if next_hi > base_hi
      next_hi = base_hi
      next_lo = next_hi - next_span
    end
  end

  return (next_lo, next_hi)
end

function _zoom_focus(area::Union{Nothing,Rect}, position)
  area === nothing && return 0.5, 0.5
  position === nothing && return 0.5, 0.5

  col, row = position
  x_denominator = max(width(area) - 1, 1)
  y_denominator = max(height(area) - 1, 1)
  x_fraction = (col - left(area)) / x_denominator
  y_fraction = 1 - (row - top(area)) / y_denominator
  return clamp(Float64(x_fraction), 0.0, 1.0), clamp(Float64(y_fraction), 0.0, 1.0)
end

function _contains(area::Rect, col::Integer, row::Integer)
  return col >= left(area) &&
         col < left(area) + width(area) &&
         row >= top(area) &&
         row < top(area) + height(area)
end

@testset "unicode-plot-render-fits-target-size" begin
  plot = UnicodePlot(UnicodePlots.lineplot, 1:5, [1, 4, 9, 16, 25]; width = 30, height = 10)
  lines = _unicode_plot_text_lines(plot, 30, 10)

  @test length(lines) <= 10
  @test _text_width(lines) <= 30
  @test any(occursin("┌", line) || occursin("⠤", line) for line in lines)
end

@testset "unicode-plot-renders-into-buffer" begin
  plot = UnicodePlot(UnicodePlots.lineplot, 1:5, [1, 4, 9, 16, 25]; width = 30, height = 10)
  buf = Buffer(Rect(1, 1, 30, 10))

  render(plot, Rect(1, 1, 30, 10), buf)

  @test any(cell.content != ' ' for cell in buf.content)
  @test plot.base_xlim !== nothing
  @test plot.base_ylim !== nothing
end

@testset "unicode-plot-mouse-wheel-zooms" begin
  plot = UnicodePlot(UnicodePlots.lineplot, 1:5, [1, 4, 9, 16, 25]; width = 30, height = 10)
  buf = Buffer(Rect(1, 1, 30, 10))
  render(plot, Rect(1, 1, 30, 10), buf)

  base_xlim = plot.base_xlim
  evt = Crossterm.Event{Crossterm.MouseEvent}(
    Crossterm.EventTag.MOUSE,
    Crossterm.MouseEvent("ScrollUp", 14, 4, String[]),
  )

  @test handle_event!(plot, evt)
  @test plot.xlim !== nothing
  @test plot.xlim[2] - plot.xlim[1] < base_xlim[2] - base_xlim[1]
end
