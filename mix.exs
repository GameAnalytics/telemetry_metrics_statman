defmodule TelemetryMetricsStatman.MixProject do
  use Mix.Project

  def project do
    [
      app: :telemetry_metrics_statman,
      version: "0.1.0",
      elixir: "~> 1.10",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:telemetry_metrics, "~> 0.6.2 or ~> 1.0"},
      {:statman, github: "GameAnalytics/statman", tag: "v0.13"},
      {:dialyxir, "~> 1.0", only: [:dev], runtime: false},
      {:credo, "~> 1.4", only: [:dev, :test], runtime: false},
      {:mock, "~> 0.3", only: :test},
    ]
  end
end
