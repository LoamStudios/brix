defmodule Brix.MixProject do
  use Mix.Project

  def project do
    [
      app: :brix,
      version: "0.1.0",
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps()
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
      {:earmark, "~> 1.4"},
      {:phoenix_live_view, "~> 1.0"}
    ]
  end
end
