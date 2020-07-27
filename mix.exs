defmodule Highlander.MixProject do
  use Mix.Project

  def project do
    [
      app: :highlander,
      version: "0.2.1",
      elixir: "~> 1.9",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      name: "Highlander",
      source_url: "https://github.com/derekkraan/highlander",
      elixirc_paths: elixirc_paths(Mix.env())
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
      {:ex_doc, "~> 0.21.3", only: :dev},
      {:local_cluster, "~> 1.1", only: :test},
      {:schism, "~> 1.0.1", only: :test}
    ]
  end

  defp package do
    [
      description: "There can only be one! (process in your cluster)",
      licenses: ["MIT"],
      maintainers: ["Derek Kraan"],
      links: %{GitHub: "https://github.com/derekkraan/highlander"}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]
end
