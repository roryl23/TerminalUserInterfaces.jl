# Usage

To use it in Julia, first add it:

```
(v1.9)> add TerminalUserInterfaces
```

All `TerminalUserInterfaces` application follow "The Elm Architecture" pattern.

Here's an example of a ProgressBar:

```julia
using TerminalUserInterfaces
const TUI = TerminalUserInterfaces
using REPL
using InteractiveUtils

@kwdef mutable struct Model <: TUI.Model
  quit = false
  counter = 1
  max_count = 1000
end

function TUI.view(m::Model)
  b = TUI.Block(; border = TUI.BorderAll)
  pg = TUI.ProgressBar(;
    block = b,
    ratio = m.counter / m.max_count,
    crayon = TUI.Crayon(; foreground = :black, background = :white),
    inv_crayon = TUI.Crayon(; foreground = :white, background = :black),
  )
  pg
end

function TUI.update!(m::Model, ::Nothing)
  m.counter += 1
  if m.counter >= m.max_count
    m.quit = true
  end
end

function TUI.update!(m::Model, evt::TUI.KeyEvent)
  if TUI.keypress(evt) == "q"
    m.quit = true
  end
end

function main(max_count)
  TUI.app(Model(; max_count))
end

main(100)
```

![](https://user-images.githubusercontent.com/1813121/273422166-fe14909f-61f3-4595-9006-1c32f64b5869.gif)

## UnicodePlots

`UnicodePlot` wraps any UnicodePlots plot constructor and renders it as a TUI widget. Keep the
plot object on the model when you want mouse wheel zoom state to persist between frames, and enable
mouse capture when starting the app.

```julia
using TerminalUserInterfaces
const TUI = TerminalUserInterfaces
const UP = TUI.UnicodePlots

@kwdef mutable struct Model <: TUI.Model
  quit = false
  plot::TUI.UnicodePlot
end

function Model()
  xs = range(0, 2pi; length = 180)
  ys = sin.(xs)
  plot = TUI.UnicodePlot(
    UP.lineplot,
    collect(xs),
    ys;
    block = TUI.Block(; title = "UnicodePlots"),
    width = 72,
    height = 20,
    xlabel = "x",
    ylabel = "sin(x)",
    compact = true,
  )
  Model(false, plot)
end

TUI.view(m::Model) = m.plot

function TUI.update!(m::Model, evt::TUI.KeyEvent)
  if TUI.keypress(evt) == "q"
    m.quit = true
  elseif TUI.keypress(evt) == "r"
    TUI.reset_zoom!(m.plot)
  end
end

TUI.app(Model(); mouse = true)
```
