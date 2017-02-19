defmodule RateLimit.Application do
  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    # Define workers and child supervisors to be supervised
    children = [
      # Starts a worker by calling: RateLimit.Worker.start_link(arg1, arg2, arg3)
      # worker(RateLimit.Worker, [arg1, arg2, arg3]),
      supervisor(RateLimit.LimiterSupervisor, []),
      supervisor(RateLimit.Controller, []),
      Plug.Adapters.Cowboy.child_spec(:http, RateLimit.Router, [], [port: 4001])
    ]

    # See http://elixir-lang.org/docs/stable/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: RateLimit.Supervisor]
    RateLimit.Stats.connect
    {:ok, pid} = Supervisor.start_link(children, opts)
    RateLimit.Limiter.start_limiters(:multi_test, 1000)
    {:ok, pid}
  end
end
