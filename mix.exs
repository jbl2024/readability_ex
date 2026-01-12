defmodule ReadabilityEx.MixProject do
  use Mix.Project

  def project do
    [
      app: :readability_ex,
      version: "0.1.0",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
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
      {:floki, "~> 0.38"},
      {:jason, "~> 1.4"}
    ]
  end

  def cli do
    [
      preferred_envs: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test,
        "test.watch": :test,
        precommit: :test
      ]
    ]
  end

  defp aliases do
    [
      precommit: ["format --check-formatted", "test"]
    ]
  end
end
