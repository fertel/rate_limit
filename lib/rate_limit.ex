defmodule RateLimit do
  def update_ex_rated(duration, count) do
    Application.put_env(:rate_limit, :ex_rated, [:exrated_test, duration, count] )
  end
end
