defmodule RateLimit.Router do
  use Plug.Router
  @json   %{"at" => 2,
   "bcat" => ["IAB26", "BSW4", "IAB25-3", "IAB7", "BSW2", "BSW10", "BSW1",
    "IAB7-17"], "cur" => ["USD"],
   "device" => %{"connectiontype" => 0, "devicetype" => 2,
     "geo" => %{"city" => "Overland Park", "country" => "US", "region" => "KS",
       "zip" => "66213"}, "ip" => "99.121.104.11", "js" => 1,
     "language" => "en",
     "ua" => "Mozilla/5.0 (Windows NT 10.0; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Spotify/1.0.28.87 Safari/537.36"},
   "ext" => %{"clktrkrq" => 0, "is_secure" => 0, "ssp" => "rubicon", "wt" => 1},
   "id" => "6161e246-f22e-4fba-a494-287cbb2f3964",
   "imp" => [%{"banner" => %{"battr" => [1, 2, 3, 5, 6, 7, 8, 9, 10, 12, 13,
         14], "btype" => [1], "h" => 90, "pos" => 1, "topframe" => 0,
        "w" => 728}, "bidfloor" => 0.011124, "bidfloorcur" => "USD",
      "exp" => 300, "ext" => %{"rubicon" => %{"site_size_session_count" => 0}},
      "id" => "1", "instl" => 0, "secure" => 0, "tagid" => "rubicon_307554"}],
   "site" => %{"cat" => ["IAB1"], "domain" => "spotify.com", "ext" => %{},
     "id" => "rubicon_2033777", "name" => "https://www.spotify.com",
     "page" => "https://www.spotify.com",
     "publisher" => %{"id" => "rubicon_209724", "name" => ""}}, "tmax" => 99,
   "user" => %{"ext" => %{"ug" => 0},
     "id" => "2648046b-e91c-4f1f-aa67-0504511c21e3"}, "wseat" => ["98"]} |> Poison.encode!
  plug :match
  plug :dispatch

  get "/ex_rated" do
    start_time  = System.system_time(:microseconds)
    do_stuff
    {t, should_throttle} = :timer.tc(ExRated,:check_rate,[:ex_rated_test, 100, 300])
    {limited,result} = case should_throttle do
      {:ok, _}->
        {false, send_resp(conn, 204,"")}
      {:error,_}->
        # {_,_,time_to_next,_,_} = ExRated.inspect_bucket(:ex_rated_test, 1000, 6000)
        # RateLimit.Stats.histogram("ex_rated.time_to_next", time_to_next, [sample_rate: 0.2] )
        {true, send_resp(conn, 429, "")}
    end
    RateLimit.Stats.increment("ex_rated", 1, [sample_rate: 0.2, tags: ["limited:#{limited}"]] )
    RateLimit.Stats.histogram("ex_rated.f.t", t, sample_rate: 0.2 )
    RateLimit.Stats.histogram("ex_rated.t", (System.system_time(:microseconds) - start_time), sample_rate: 0.2  )
    result
  end
  get "/multi_bucket" do
    start_time  = System.system_time(:microseconds)
    do_stuff
    {t, should_throttle} = :timer.tc(RateLimit.Limiter,:limit, [:multi_test])
    {limited,result} = if should_throttle do
        {true, send_resp(conn, 429, "")}
      else
        {false, send_resp(conn, 204,"")}
    end
    RateLimit.Stats.increment("multi", 1, [sample_rate: 0.2, tags: ["limited:#{limited}"]] )
    RateLimit.Stats.histogram("multi.f.t", t, sample_rate: 0.2 )
    RateLimit.Stats.histogram("multi.t", System.system_time(:microseconds) - start_time, sample_rate: 0.2  )
    result

  end
  get "/leaky_bucket" do

  end
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
