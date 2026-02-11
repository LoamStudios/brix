defmodule Brix.MixProject do
  use Mix.Project

  def project do
    [
      app: :brix,
      version: "0.1.0",
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      name: "Brix",
      source_url: "https://github.com/LoamStudios/brix",
      docs: [
        main: "Brix",
        extras: [
          "README.md",
          "cheatsheets/api.cheatmd",
          "cheatsheets/content-structure.cheatmd",
          "cheatsheets/rendering.cheatmd",
          "cheatsheets/cli.cheatmd"
        ],
        groups_for_extras: [
          Cheatsheets: ~r/cheatsheets\/.*/
        ]
      ]
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:yaml_elixir, "~> 2.11"},
      {:mdex, "~> 0.2"},
      {:phoenix_live_view, "~> 1.0"},
      {:ex_doc, "~> 0.35", only: :dev, runtime: false}
    ]
  end
end
