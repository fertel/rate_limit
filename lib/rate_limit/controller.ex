defmodule RateLimit.Controller do
  #todo: make this distributed
  use GenServer
  require Logger
  @start_count 1000

  def start_link do
    GenServer.start_link __MODULE__, [], [name: __MODULE__]
  end
  def init(_) do
    :ets.new(:rate_limiters, [:named_table, :public, read_concurrency: true])
    :ets.new(:rate_limiter_count, [:named_table, :public, read_concurrency: true])
    register
    {:ok,%{}}
  end
  def handle_call(:register_controller, {sender, _tag}, state) do
    Process.monitor(sender)
    update_pool(state)
    {:reply, :ok, state}
  end
  def handle_call({:update_pool, key, rate},_from, state) do
    state = Map.put(state,key,rate)
    update_pool(state)
    {:reply, :ok, state}
  end
  def handle_info({:DOWN, _, _, _, _}, state) do
    update_pool(state)
    {:noreply, state}
  end
  def terminate(_reason,state) do
    #need to restart throttling - should probably put them in different sup have this start and stop them
    # Enum.each fn(k,v)->
    #   CustomerThottler.stop
    # end
    #store in ets to reload...
    Logger.debug "controller crashed?"

    :ok
  end
  def start_limiters(key,count) do
    GenServer.call(__MODULE__, {:update_pool, key, count})
  end
  def stop do
    GenServer.call(__MODULE__,:stop)
  end
  defp update_pool(buckets) do
    node_count = :pg2.get_members(__MODULE__) |> length #the total number of controllers in the cluster
    Enum.each(buckets, fn {key,count} ->
      if count do
        RateLimit.Limiter.start_limiters(key, count)
      else
        RateLimit.Limiter.stop(key)
      end
    end)
  end
  defp register do
    :pg2.create(__MODULE__)
    :pg2.join(__MODULE__, self)
    #todo: we will get more complicated with this if and when we are more clever about load
    __MODULE__
    |> :pg2.get_members()
    |> Enum.each(fn
      (pid) when pid != self ->
        Process.monitor(pid)
        GenServer.call(pid, :register_controller)
      _-> :ok
    end)
  end

end
