defmodule RateLimit.Router do
  use Plug.Router
  @json   %{"at" => 2,
   "bcat" => ["IAB26", "BSW4", "IAB25-3", "IAB7", "BSW2", "BSW10", "BSW1",
    "IAB7-17"], "cur" => ["USD"],
   "device" => %{"connectiontype" => 0, "devicetype" => 2,
     "geo" => %{"city" => "New York", "country" => "US", "region" => "NY",
       "zip" => "11211"}, "ip" => "127.0.0.1", "js" => 1,
     "language" => "en",
     "ua" => "Mozilla/5.0 (Windows NT 10.0; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Spotify/1.0.28.87 Safari/537.36"},
   "ext" => %{},
   "id" => "anid",
   "imp" => [%{"banner" => %{"battr" => [1, 2, 3, 5, 6, 7, 8, 9, 10, 12, 13,
         14], "btype" => [1], "h" => 90, "pos" => 1, "topframe" => 0,
        "w" => 728}, "bidfloor" => 0.011124, "bidfloorcur" => "USD",
      "exp" => 300, "ext" => %{},
      "id" => "1", "instl" => 0, "secure" => 0, "tagid" => "1235"}],
   "site" => %{"cat" => ["IAB1"], "domain" => "spotify.com", "ext" => %{},
     "id" => "1234343535", "name" => "https://www.example.com",
     "page" => "https://www.example.com",
     "publisher" => %{"id" => "1234", "name" => ""}}, "tmax" => 99,
   "user" => %{"ext" => %{"ug" => 0},
     "id" => "bid_request_id"}, "wseat" => ["999"]} |> Poison.encode!
  plug :match
  plug :dispatch

  get "/ex_rated" do
    start_time  = System.system_time(:microseconds)
    config = Application.get_env(:rate_limit, :ex_rated)
    limited = case apply(ExRated,:inspect_bucket,config) do
      {_,0,_,_,_}->
        true
      _->
        do_stuff
        case apply(ExRated,:check_rate, config) do
          {:ok, _}->
            false
          {:error,_}->
            true
        end
    end
    RateLimit.Stats.increment("ex_rated", 1, [sample_rate: 0.1, tags: ["limited:#{limited}"]] )
    RateLimit.Stats.histogram("ex_rated.t", (System.system_time(:microseconds) - start_time), sample_rate: 0.1  )
    if limited do
      send_resp(conn, 429, "")
    else
      send_resp(conn, 204, "")
    end
  end
  get "/multi_bucket" do
    start_time  = System.system_time(:microseconds)
    limited = if RateLimit.Limiter.check_limit(:multi_test) do
      true
    else
      do_stuff
      RateLimit.Limiter.limit(:multi_test)
    end

    RateLimit.Stats.increment("multi", 1, [sample_rate: 0.1, tags: ["limited:#{limited}"]] )
    RateLimit.Stats.histogram("multi.t", System.system_time(:microseconds) - start_time, sample_rate: 0.1  )
    if limited do
      send_resp(conn, 429, "")
    else
      send_resp(conn, 204,"")
    end

  end
  get "/gen_stage" do

  end
  #todo: gen_Stage leaky bucket
  def do_stuff do
    tasks = Enum.map(1..2, &Task.async(fn -> &1;
      Poison.decode! @json
    end))
    Task.yield_many(tasks, 10)
  end


  match _ do
    send_resp(conn, 404, "oops")
  end
end
