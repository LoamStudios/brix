defmodule Brix.MixProject do
  use Mix.Project

  def project do
    [
      app: :brix,
      version: "0.1.1",
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      name: "Brix",
      description:
        "A structured content layer for Phoenix LiveView apps: YAML and Markdown files, validated, loaded, and served.",
      package: package(),
      source_url: "https://github.com/LoamStudios/brix",
      docs: [
        main: "readme",
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

  defp package do
    [
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/LoamStudios/brix"},
      files: ~w(lib cheatsheets .formatter.exs mix.exs README.md LICENSE usage-rules.md)
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
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.35", only: :dev, runtime: false}
    ]
  end
end
