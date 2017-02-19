defmodule RateLimit.Mixfile do
  use Mix.Project

  def project do
    [app: :rate_limit,
     version: "0.1.0",
     elixir: "~> 1.4",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps()]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    # Specify extra applications you'll use from Erlang/Elixir
    [extra_applications: [:logger, :ex_rated, :plug, :gen_stage, :limiter,:poison, :recon],
     mod: {RateLimit.Application, []}]
  end

  # Dependencies can be Hex packages:
  #
  #   {:my_dep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:my_dep, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
  #
  # Type "mix help deps" for more examples and options
  defp deps do
    [{:ex_rated, "~> 1.3"},
    {:plug, "~> 1.3"},
    {:gen_stage, "~> 0.11.0"},
    {:limiter, "~> 0.1.2"},
    {:cowboy, "~> 1.1"},
    {:statix, "~> 1.0"},
    {:poison, "~> 3.1"},
    {:recon, "~> 2.3"}
  ]
  end
end
