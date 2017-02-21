defmodule RateLimit.SimpleLimiter do
  use GenServer
  require Logger
  defstruct [:period,
    :limit, :count, :total_count,
    :wait_until]

  def start(opts) do
    GenServer.start(__MODULE__,opts,[])
  end
  def init(opts) do
    :pg2.create(__MODULE__)
    :pg2.join(__MODULE__, self())
    period = opts[:period]
    {:ok,%__MODULE__{
      wait_until: System.system_time(:milliseconds) + period,
      count: 0,
      total_count: 0,
      limit: opts[:limit],
      period: period
    }}
  end
  def handle_call({:limit, weight},_from,state) do
    now = System.system_time(:milliseconds)
    cond do
      state.count >= state.limit && state.wait_until > now ->
        {:reply, true, %{state | total_count: state.total_count + weight}}
      state.wait_until < now ->
        {:reply, false,  %{state |  wait_until: now + state.period, count: weight, total_count: weight }}
      true ->
        {:reply, false, %{state |  count: state.count + weight, total_count: state.total_count + weight }}
    end
  end
  def handle_call(:stop,_from,state) do
    Logger.debug "stopping simple limiter"
    {:stop, :normal, state}
  end
  def handle_cast({:do_update, period, limit}, state) do
    {:noreply, %{state | period: period, limit: limit, wait_until: System.system_time(:milliseconds) + period }}
  end
  def update(period,limit) do
    GenServer.cast(limiter(), {:do_update,period,limit})
  end
  def stop do
    GenServer.call(limiter, :stop)
  end
  defp limiter do
    :pg2.get_closest_pid(__MODULE__)
  end
  def check_limit do
    GenServer.call(limiter, {:limit, 0})
  end
  def limit do
    GenServer.call(limiter, {:limit, 1})
  end

end
