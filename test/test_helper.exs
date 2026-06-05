# `:pro`-tagged tests exercise the closed-source `vendor/pro` modules and only
# pass when that submodule is compiled in. They are excluded by default so the
# open-core suite (and any clone without `vendor/pro`) stays green; the Pro CI
# leg opts back in with `mix test --include pro`.
ExUnit.start(exclude: [:pro])
Ecto.Adapters.SQL.Sandbox.mode(Typster.Repo, :manual)
