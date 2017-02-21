defmodule RateLimit.Limiter do
  use GenServer
  require Logger


  #for now token bucket but distributed amongst lots of buckets on  a very small time scale
  defstruct [:name, :period,
    :limit, :limiter_count,
    :ix, :count, :total_count,
    :wait_until, :previous_in]


  def start_limiters(name,limit, node_count  \\ 1) do
    #:erlang.system_info :schedulers # decide this based on count

    state = build_state(name, limit, node_count)
    case :ets.lookup(:rate_limiter_count, name) do
      [{_, count}]->
        cond do
         count > state.limiter_count ->
          :ets.insert(:rate_limiter_count, {name, state.limiter_count})
          Enum.each((state.limiter_count + 1) .. count,fn (ix)->
            load_limiter_ix(name,ix)
            |> GenServer.call(:stop)
          end)
        count < state.limiter_count ->
          Enum.each((count + 1).. state.limiter_count, fn (ix) ->
            RateLimit.LimiterSupervisor.start_child(%{state | ix: ix})
            :timer.sleep(3)
          end)
          :ets.insert(:rate_limiter_count, {name, state.limiter_count})
        true ->
          :ok
        end
        update_state(name, state)
      []->
        :ets.insert(:rate_limiter_count, {name, state.limiter_count})
        Enum.each(1..state.limiter_count, fn(ix)->
          RateLimit.LimiterSupervisor.start_child(%{state | ix: ix})
          :timer.sleep(10)
        end)
    end

    Logger.debug "starting #{state.limiter_count} with limit: #{state.limit} and period: #{state.period}"

  end

  def start_link(opts) do
    GenServer.start_link(__MODULE__,opts,[])
  end
  def init(state) do


    register(state)
    {:ok,%{
      state | wait_until: System.system_time + state.period,
      count: 0,
      previous_in: [],
      total_count: 0
    }}
  end
  def handle_call({:limit, weight},_from,state) do
    now = System.system_time
    cond do
      state.count >= state.limit && state.wait_until > now ->
        {:reply, true, %{state | total_count: state.total_count + weight}}
      state.wait_until < now ->
        {:reply, false,  %{state |  wait_until: now + state.period, count: weight, total_count: weight }}
      true ->
        {:reply, false, %{state |  count: state.count + weight, total_count: state.total_count + weight }}
    end
  end
  def handle_call(:stop,_from, state) do
   {:stop, :normal, :ok, state}
  end
  def handle_cast({:update_state, new_state},state) do
    Logger.debug "updating state"
    {:noreply, %{state | name: new_state.name,
      period: new_state.period, limit: new_state.limit,
      limiter_count: new_state.limiter_count  }}
  end
  def check_limit(name) do
    case load_limiter_ix(name) do
      nil ->
        :ok
      pid ->
        GenServer.call(pid, {:limit, 0})
    end
  end
  def limit(name) do
    case load_limiter_ix(name) do
      nil -> :ok
      pid ->
        GenServer.call(pid, {:limit, 1})
    end
  end
  def update_state(name, state) do
    Enum.each(load_limiters(name), fn (pid)->
      GenServer.cast(pid, {:update_state, state})
    end)
  end
  def terminate(reason,state) do
    :ets.delete(:rate_limiters, {state.name, state.ix})
    :ok
  end

  def stop(name) do

    Enum.each(load_limiters(name), fn (pid)->
      GenServer.call(pid, :stop)
    end)
    :ets.delete(:rate_limiter_count,name) #well make this a counter in a sec
  end


  defp register(state) do
    :ets.insert(:rate_limiters,{{state.name, state.ix}, self})
  end
  def load_limiter_ix(name) do
    case :ets.lookup(:rate_limiter_count,name) do #note this can be modified by grabbing known state
      [{^name, count}]->
        limiter_ix = :rand.uniform(count)
        [{_, pid}] = :ets.lookup(:rate_limiters,{name, limiter_ix})
        pid
      []->
        nil
    end
  end
  def load_limiter_ix(name, ix) do
    [{_,pid}] = :ets.lookup(:rate_limiters, {name, ix})
    pid
  end
  def load_limiters(name) do
    case :ets.lookup(:rate_limiter_count,name) do
      [{^name, count}]->
        Enum.map(1..count, fn (ix)->
          [{_,pid}] = :ets.lookup(:rate_limiters, {name, ix})
          pid
        end)
      []->
        []
    end
  end
  #need a good explanation for these numbers
  def build_state(name, limit, node_count) do
    Logger.debug "building state for #{name} with qps #{limit} and node_count #{node_count}"
    node_qps = div(limit, node_count)
    node_qps = node_qps > 0 && node_qps || 1
    period  =  div(1000, node_qps)
    if period  <= 100 do
      limit = div(node_qps, 10)
      remainder = rem(node_qps, 200)

      limiter_count = case div(limit, 10) do
        val when val <= 1 -> 1
        val -> val
      end
      limit = div(limit, limiter_count)
      %__MODULE__{
        limit: limit,
        limiter_count: limiter_count,
        period:  100 * :math.pow(1000, 2),
        name: name
      }
    else
      %__MODULE__{
        limit: 1,
        period: :math.pow(1000,2 ) * period,
        limiter_count: 1,
        name: name
      }
    end
  end
end
