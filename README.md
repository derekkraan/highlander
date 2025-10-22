# Highlander
<!-- MDOC !-->

Highlander allows you to run a single globally unique process in a cluster. (h/t [@tuxified](https://github.com/tuxified) for the name)

Highlander uses erlang's `:global` module to ensure uniqueness, and uses `child_spec.id` as the uniqueness key.

Highlander will start its child process just once in a cluster. The first Highlander process will start its child, all other Highlander processes will monitor the first process and attempt to take over when it goes down.

_Note: You can also use Highlander to start a globally unique supervision tree._

## HighlanderPG

Highlander has a sister library called [HighlanderPG](https://github.com/derekkraan/highlander_pg), which is backed by Postgres advisory locks. If you need better guarantees of uniqueness or can not use erlang clustering (eg, in Heroku) then this library can be a good alternative.

Subscriptions to HighlanderPG support its maintenance and further development.

## Usage
Simply wrap a child process with `{Highlander, child}`.

Before:

```
children = [
  child_spec
]

Supervisor.init(children, strategy: :one_for_one)
```

After:

```
children = [
  {Highlander, child_spec}
]

Supervisor.init(children, strategy: :one_for_one)
```

See the [documentation on Supervisor.child_spec/1](https://hexdocs.pm/elixir/Supervisor.html#module-child_spec-1) for more information.

## Determining global uniqueness

`child_spec.id` is used to determine global uniqueness. Check the debug logs if you are unsure what is being used.

## Globally unique supervisors

You can also have Highlander run a supervisor:

```
children = [
  {Highlander, {MySupervisor, arg}},
]
```

## Handling netsplits

If there is a netsplit in your cluster, then Highlander will think that the other process has died, and start a new one. When the split heals, `:global` will recognize that there is a naming conflict, and will take action to rectify that. To deal with this, Highlander simply terminates one of the two child processes with reason `:shutdown`.

To catch this, simply trap exits in your process and add a `terminate/2` callback.

Note: The `terminate/2` callback will also run when your application is terminating.

```
def init(arg) do
  Process.flag(:trap_exit, true)
  {:ok, initial_state(arg)}
end

def terminate(_reason, _state) do
  # this will run when the process receives an exit signal from its parent
end
```
