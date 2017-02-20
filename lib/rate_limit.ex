defmodule RateLimit do
  def update_ex_rated(duration, count) do
    Application.put_env(:rate_limit, :ex_rated, [:exrated_test, duration, count] )
  end
  def update_limiters(count) do
    RateLimit.Limiter.start_limiters(:multi_test, count)
  end
  def multi_backup_avg do
    limiters = RateLimit.Limiters.load_limiter(:multi_test)
    Enum.reduce(limiters, 0,
      fn (pid, acc )-> :recon.info(pid)[:memory_used][:message_queue_len] + acc end) / length(limiters)
  end
  def ex_rated_backup do
    info = :ex_rated
    |> Process.whereis
    |> :recon.info
    info[:memory_used][:message_queue_len]
  end
end
