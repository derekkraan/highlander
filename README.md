# Highlander

There can only be one [process in your cluster]! (h/t @tuxified for the name)

Highlander ensures that your process only runs once in your system. It is based on erlang's `:global`.

The entire library is only about 50 lines of code, and has no additional dependencies. So please feel free to read the source.

# [Read the documentation](https://hexdocs.pm/highlander) for usage instructions.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `highlander` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:highlander, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/highlander](https://hexdocs.pm/highlander).

