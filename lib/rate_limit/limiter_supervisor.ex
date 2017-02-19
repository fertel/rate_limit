defmodule RateLimit.LimiterSupervisor do
  use Supervisor
  require Logger
  import Supervisor.Spec, warn: false
  def start_link do
   Supervisor.start_link(__MODULE__, [], name: __MODULE__)
 end
 def init([]) do
   children = [
     worker(RateLimit.Limiter, [], restart: :transient)
   ]
   supervise(children, strategy: :simple_one_for_one)
 end
 def start_child(state) do
   Supervisor.start_child(__MODULE__,[state])
 end
 def stop_child(pid) do
   Supervisor.terminate_child(__MODULE__, pid)
 end
end
