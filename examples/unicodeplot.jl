using TerminalUserInterfaces
const TUI = TerminalUserInterfaces
const UP = TUI.UnicodePlots

@kwdef mutable struct Model <: TUI.Model
  quit = false
  plot::TUI.UnicodePlot
end

function Model()
  xs = range(0, 2pi; length = 180)
  ys = sin.(xs) .+ 0.25 .* cos.(3 .* xs)
  plot = TUI.UnicodePlot(
    UP.lineplot,
    collect(xs),
    ys;
    block = TUI.Block(; title = "UnicodePlots"),
    width = 72,
    height = 20,
    xlabel = "x",
    ylabel = "value",
    compact = true,
  )
  return Model(false, plot)
end

function TUI.view(m::Model)
  return m.plot
end

function TUI.update!(m::Model, evt::TUI.KeyEvent)
  if TUI.keypress(evt) == "q"
    m.quit = true
  elseif TUI.keypress(evt) == "r"
    TUI.reset_zoom!(m.plot)
  end
end

function main()
  TUI.app(Model(); mouse = true)
end

main()
