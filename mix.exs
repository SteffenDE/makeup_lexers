defmodule MakeupLexers.MixProject do
  use Mix.Project

  def project do
    [
      app: :makeup_lexers,
      version: "0.1.0",
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      docs: [
        main: "readme",
        extras: Path.wildcard("examples/*.md") ++ ["README.md"],
        source_url: "https://github.com/SteffenDE/makeup_lexers"
      ],
      preferred_cli_env: [
        docs: :docs
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {MakeupLexers.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
      {:nimble_parsec, "~> 1.4"},
      {:makeup, "~> 1.2"},
      {:makeup_eex, "~> 1.0", only: :docs},
      {:makeup_elixir,
       github: "elixir-makeup/makeup_elixir", branch: "master", only: :docs, override: true},
      {:ex_doc, "~> 0.34", only: :docs, runtime: false}
    ]
  end
end
