defmodule MatchingEngineTest do
  use ExUnit.Case

  alias Exchange.{MatchingEngine, Order, OrderBook}

  describe "Spread, bid_max and ask_min queries unit tests" do
    setup _context do
      {:ok, %{order_book: empty_order_book()}}
    end

    test "empty order book", %{order_book: order_book} do
      {_response_code, {:ok, spread}, _state} = MatchingEngine.handle_call(:spread, nil, order_book)
      {_response_code, {:ok, ask_min}, _state} = MatchingEngine.handle_call(:ask_min, nil, order_book)
      {_response_code, {:ok, bid_max}, _state} = MatchingEngine.handle_call(:bid_max, nil, order_book)
      assert spread == %Money{amount: 99_998, currency: :GBP}
      assert ask_min == %Money{amount: 99_999, currency: :GBP}
      assert bid_max == %Money{amount: 1, currency: :GBP}
    end

    test "after one buy order", %{order_book: order_book} do
      order_book = OrderBook.price_time_match(order_book, sample_order(%{size: 1000, price: 4000, side: :buy}))
      {_response_code, {:ok, spread}, _state} = MatchingEngine.handle_call(:spread, nil, order_book)
      {_response_code, {:ok, ask_min}, _state} = MatchingEngine.handle_call(:ask_min, nil, order_book)
      {_response_code, {:ok, bid_max}, _state} = MatchingEngine.handle_call(:bid_max, nil, order_book)
      assert spread == %Money{amount: 95_999, currency: :GBP}
      assert ask_min == %Money{amount: 99_999, currency: :GBP}
      assert bid_max == %Money{amount: 4000, currency: :GBP}
    end

    test "spread after one sell order", %{order_book: order_book} do
      order_book = OrderBook.price_time_match(order_book, sample_order(%{size: 500, price: 3900, side: :sell}))
      {_response_code, {:ok, spread}, _state} = MatchingEngine.handle_call(:spread, nil, order_book)
      {_response_code, {:ok, ask_min}, _state} = MatchingEngine.handle_call(:ask_min, nil, order_book)
      {_response_code, {:ok, bid_max}, _state} = MatchingEngine.handle_call(:bid_max, nil, order_book)
      assert spread == %Money{amount: 3899, currency: :GBP}
      assert ask_min == %Money{amount: 3900, currency: :GBP}
      assert bid_max == %Money{amount: 1, currency: :GBP}
    end

    test "spread after several order", %{order_book: order_book} do
      {_response_code, {:ok, spread_1}, _state} = MatchingEngine.handle_call(:spread, nil, order_book)
      {_response_code, {:ok, ask_min_1}, _state} = MatchingEngine.handle_call(:ask_min, nil, order_book)
      {_response_code, {:ok, bid_max_1}, _state} = MatchingEngine.handle_call(:bid_max, nil, order_book)
      order_book = OrderBook.price_time_match(order_book, sample_order(%{size: 1000, price: 4000, side: :buy}))
      {_response_code, {:ok, spread_2}, _state} = MatchingEngine.handle_call(:spread, nil, order_book)
      {_response_code, {:ok, ask_min_2}, _state} = MatchingEngine.handle_call(:ask_min, nil, order_book)
      {_response_code, {:ok, bid_max_2}, _state} = MatchingEngine.handle_call(:bid_max, nil, order_book)
      order_book = OrderBook.price_time_match(order_book, sample_order(%{size: 500, price: 3900, side: :sell}))
      {_response_code, {:ok, spread_3}, _state} = MatchingEngine.handle_call(:spread, nil, order_book)
      {_response_code, {:ok, ask_min_3}, _state} = MatchingEngine.handle_call(:ask_min, nil, order_book)
      {_response_code, {:ok, bid_max_3}, _state} = MatchingEngine.handle_call(:bid_max, nil, order_book)
      order_book = OrderBook.price_time_match(order_book, sample_order(%{size: 1000, price: 3900, side: :sell}))
      {_response_code, {:ok, spread_4}, _state} = MatchingEngine.handle_call(:spread, nil, order_book)
      {_response_code, {:ok, ask_min_4}, _state} = MatchingEngine.handle_call(:ask_min, nil, order_book)
      {_response_code, {:ok, bid_max_4}, _state} = MatchingEngine.handle_call(:bid_max, nil, order_book)
      order_book = OrderBook.price_time_match(order_book, sample_order(%{size: 250, price: 3800, side: :buy}))
      {_response_code, {:ok, spread_5}, _state} = MatchingEngine.handle_call(:spread, nil, order_book)
      {_response_code, {:ok, ask_min_5}, _state} = MatchingEngine.handle_call(:ask_min, nil, order_book)
      {_response_code, {:ok, bid_max_5}, _state} = MatchingEngine.handle_call(:bid_max, nil, order_book)

      assert spread_1 == %Money{amount: 99_998, currency: :GBP}
      assert spread_2 == %Money{amount: 95_999, currency: :GBP}
      assert spread_3 == %Money{amount: 95_999, currency: :GBP}
      assert spread_4 == %Money{amount: 3899, currency: :GBP}
      assert spread_5 == %Money{amount: 100, currency: :GBP}
      assert ask_min_1 == %Money{amount: 99_999, currency: :GBP}
      assert ask_min_2 == %Money{amount: 99_999, currency: :GBP}
      assert ask_min_3 == %Money{amount: 99_999, currency: :GBP}
      assert ask_min_4 == %Money{amount: 3900, currency: :GBP}
      assert ask_min_5 == %Money{amount: 3900, currency: :GBP}
      assert bid_max_1 == %Money{amount: 1, currency: :GBP}
      assert bid_max_2 == %Money{amount: 4000, currency: :GBP}
      assert bid_max_3 == %Money{amount: 4000, currency: :GBP}
      assert bid_max_4 == %Money{amount: 1, currency: :GBP}
      assert bid_max_5 == %Money{amount: 3800, currency: :GBP}
    end
  end

  describe "Expirations" do
    setup _context do
      {:ok, %{order_book: sample_order_book(:AUXLND)}}
    end

    test "orders with expiration are added to expiration_list", %{order_book: ob} do
      t1 = :os.system_time(:millisecond)
      t2 = :os.system_time(:millisecond) - 1000

      buy_order =
        sample_expiring_order(%{size: 1000, price: 3999, side: :buy, id: "9", exp_time: t1})

      sell_order =
        sample_expiring_order(%{size: 1000, price: 4020, side: :sell, id: "10", exp_time: t2})

      {:reply, _code, ob} = MatchingEngine.handle_call({:place_limit_order, buy_order}, nil, ob)
      {:reply, _code, ob} = MatchingEngine.handle_call({:place_limit_order, sell_order}, nil, ob)
      order_id_1 = buy_order.order_id
      order_id_2 = sell_order.order_id

      assert [{t2, order_id_2}, {t1, order_id_1}] == ob.expiration_list
    end

    test "orders fullfilled are not added to expiration_list", %{order_book: ob} do
      t1 = :os.system_time(:millisecond)

      buy_order =
        sample_expiring_order(%{size: 750, price: 4010, side: :buy, id: "9", exp_time: t1})

      new_book = OrderBook.price_time_match(ob, buy_order)
      assert [] == new_book.expiration_list
    end

    test "order is automatically cancelled on expiration time", %{order_book: ob} do
      t = :os.system_time(:millisecond) - 1
      order = sample_expiring_order(%{size: 1000, price: 3999, side: :buy, id: "9", exp_time: t})
      {:reply, _code, ob} = MatchingEngine.handle_call({:place_limit_order, order}, nil, ob)
      assert [{t, order.order_id}] == ob.expiration_list
      {:noreply, ob} = MatchingEngine.handle_info(:check_expiration, ob)
      assert [] == ob.expired_orders
    end
  end

  describe "Placing and canceling orders" do
    setup _context do
      {:ok, %{order_book: sample_order_book(:AUXLND)}}
    end

    test "Place a market buy order that consumes the top of the sell side", %{order_book: order_book} do
      order = sample_order(%{size: 2000, price: 0, side: :buy})
      order = %Order{order | type: :market}
      {:reply, _code, ob} = MatchingEngine.handle_call({:place_market_order, order}, nil, order_book)
      {_response_code, {:ok, spread}, _state} = MatchingEngine.handle_call(:spread, nil, ob)
      {_response_code, {:ok, ask_min}, _state} = MatchingEngine.handle_call(:ask_min, nil, ob)
      {_response_code, {:ok, bid_max}, _state} = MatchingEngine.handle_call(:bid_max, nil, ob)
      assert Enum.count(ob.sell) == 1
      assert spread == %Money{amount: 20, currency: :GBP}
      assert ask_min == %Money{amount: 4020, currency: :GBP}
      assert bid_max == %Money{amount: 4000, currency: :GBP}
    end

    test "Place a market sell order that consumes the top of the buy side", %{order_book: order_book} do
      order = sample_order(%{size: 750, price: 0, side: :sell})
      order = %Order{order | type: :market}
      {:reply, _code, ob} = MatchingEngine.handle_call({:place_market_order, order}, nil, order_book)
      {_response_code, {:ok, spread}, _state} = MatchingEngine.handle_call(:spread, nil, ob)
      {_response_code, {:ok, ask_min}, _state} = MatchingEngine.handle_call(:ask_min, nil, ob)
      {_response_code, {:ok, bid_max}, _state} = MatchingEngine.handle_call(:bid_max, nil, ob)
      assert Enum.count(ob.buy) == 2
      assert spread == %Money{amount: 40, currency: :GBP}
      assert ask_min == %Money{amount: 4010, currency: :GBP}
      assert bid_max == %Money{amount: 3970, currency: :GBP}
    end

    test "Place a market buy order that partially consumes the top order of the sell side", %{order_book: order_book} do
      order = sample_order(%{size: 100, price: 0, side: :buy})
      order = %Order{order | type: :market}
      {:reply, _code, ob} = MatchingEngine.handle_call({:place_market_order, order}, nil, order_book)
      partial_order = ob.sell[4010] |> Enum.find(%Order{}, fn order -> order.order_id == "1" end)
      assert Map.get(partial_order, :size) == 650
    end

    test "Place a market sell order that partially consumes the top order of the buy side", %{order_book: order_book} do
      order = sample_order(%{size: 100, price: 0, side: :sell})
      order = %Order{order | type: :market}
      {:reply, _code, ob} = MatchingEngine.handle_call({:place_market_order, order}, nil, order_book)
      partial_order = ob.buy[4000] |> Enum.find(%Order{}, fn order -> order.order_id == "4" end)
      assert Map.get(partial_order, :size) == 150
    end

    test "Place a market buy order that is partially filled", %{order_book: order_book} do
      order = sample_order(%{size: 10000, price: 0, side: :buy})
      order = %Order{order | type: :market}
      {:reply, _code, ob} = MatchingEngine.handle_call({:place_market_order, order}, nil, order_book)
      partial_order = ob.buy[ob.bid_max] |> Enum.find(%Order{}, fn order -> order.order_id == "9" end)
      assert Map.get(partial_order, :size) == 7750
    end

    test "Place a market sell order that partially filled", %{order_book: order_book} do
      order = sample_order(%{size: 10000, price: 0, side: :sell})
      order = %Order{order | type: :market}
      {:reply, _code, ob} = MatchingEngine.handle_call({:place_market_order, order}, nil, order_book)
      partial_order = ob.sell[ob.ask_min] |> Enum.find(%Order{}, fn order -> order.order_id == "9" end)
      assert Map.get(partial_order, :size) == 8350
    end

    test "Place a limit buy order that consumes the top of the sell side", %{order_book: order_book} do
      order = sample_order(%{size: 2000, price: 4010, side: :buy})
      {:reply, _code, ob} = MatchingEngine.handle_call({:place_market_order, order}, nil, order_book)
      {_response_code, {:ok, spread}, _state} = MatchingEngine.handle_call(:spread, nil, ob)
      {_response_code, {:ok, ask_min}, _state} = MatchingEngine.handle_call(:ask_min, nil, ob)
      {_response_code, {:ok, bid_max}, _state} = MatchingEngine.handle_call(:bid_max, nil, ob)
      assert Enum.count(ob.sell) == 1
      assert spread == %Money{amount: 20, currency: :GBP}
      assert ask_min == %Money{amount: 4020, currency: :GBP}
      assert bid_max == %Money{amount: 4000, currency: :GBP}
    end

    test "Place a limit sell order that consumes the top of the buy side", %{order_book: order_book} do
      order = sample_order(%{size: 750, price: 4000, side: :sell})
      {:reply, _code, ob} = MatchingEngine.handle_call({:place_limit_order, order}, nil, order_book)
      {_response_code, {:ok, spread}, _state} = MatchingEngine.handle_call(:spread, nil, ob)
      {_response_code, {:ok, ask_min}, _state} = MatchingEngine.handle_call(:ask_min, nil, ob)
      {_response_code, {:ok, bid_max}, _state} = MatchingEngine.handle_call(:bid_max, nil, ob)
      assert Enum.count(ob.buy) == 2
      assert spread == %Money{amount: 40, currency: :GBP}
      assert ask_min == %Money{amount: 4010, currency: :GBP}
      assert bid_max == %Money{amount: 3970, currency: :GBP}
    end

    test "Place a limit buy order that partially consumes the top order of the sell side", %{order_book: order_book} do
      order = sample_order(%{size: 100, price: 4010, side: :buy})
      {:reply, _code, ob} = MatchingEngine.handle_call({:place_limit_order, order}, nil, order_book)
      partial_order = ob.sell[4010] |> Enum.find(%Order{}, fn order -> order.order_id == "1" end)
      assert Map.get(partial_order, :size) == 650
    end

    test "Place a limit sell order that partially consumes the top order of the buy side", %{order_book: order_book} do
      order = sample_order(%{size: 100, price: 4000, side: :sell})
      {:reply, _code, ob} = MatchingEngine.handle_call({:place_limit_order, order}, nil, order_book)
      partial_order = ob.buy[4000] |> Enum.find(%Order{}, fn order -> order.order_id == "4" end)
      assert Map.get(partial_order, :size) == 150
    end

    test "Place a limit buy order that is partially filled", %{order_book: order_book} do
      order = sample_order(%{size: 10000, price: 4010, side: :buy})
      order = %Order{order | type: :market}
      {:reply, _code, ob} = MatchingEngine.handle_call({:place_limit_order, order}, nil, order_book)
      partial_order = ob.buy[ob.bid_max] |> Enum.find(%Order{}, fn order -> order.order_id == "9" end)
      assert Map.get(partial_order, :size) == 8000
      assert Map.get(partial_order, :initial_size) == 10000
      refute ob.sell[4010]
    end

    test "Place a limit sell order that partially filled", %{order_book: order_book} do
      order = sample_order(%{size: 10000, price: 4000, side: :sell})
      order = %Order{order | type: :market}
      {:reply, _code, ob} = MatchingEngine.handle_call({:place_limit_order, order}, nil, order_book)
      partial_order = ob.sell[ob.ask_min] |> Enum.find(%Order{}, fn order -> order.order_id == "9" end)
      assert Map.get(partial_order, :size) == 9250
      assert Map.get(partial_order, :initial_size) == 10000
      refute ob.buy[4000]
    end

    test "Place limit order with price higher than max_price", %{order_book: order_book} do
      order = sample_order(%{size: 100, price: 190_000, side: :sell})
      {:reply, code, _ob} = MatchingEngine.handle_call({:place_limit_order, order}, nil, order_book)
      assert code == :error
    end

    test "Place limit order with price lower than min_price", %{order_book: order_book} do
      order = sample_order(%{size: 100, price: 900, side: :sell})
      {:reply, code, _ob} = MatchingEngine.handle_call({:place_limit_order, order}, nil, order_book)
      assert code == :error
    end

    test "Place limit order with existing id", %{order_book: order_book} do
      order = sample_order(%{size: 100, price: 10_000, side: :sell})
      order = %Order{order | order_id: "4"}
      {:reply, code, _ob} = MatchingEngine.handle_call({:place_limit_order, order}, nil, order_book)
      assert code == :error
    end

    test "Place market order with existing id", %{order_book: order_book} do
      order = sample_order(%{size: 100, price: 10_000, side: :sell})
      order = %Order{order | type: :market, order_id: "4"}
      {:reply, code, _ob} = MatchingEngine.handle_call({:place_market_order, order}, nil, order_book)
      assert code == :error
    end

    test "Cancel existing order", %{order_book: order_book} do
      {:reply, code, _ob} = MatchingEngine.handle_call({:cancel_order, "4"}, nil, order_book)
      assert code == :ok
    end

    test "Cancel inexisting order", %{order_book: order_book} do
      {:reply, code, _ob} = MatchingEngine.handle_call({:cancel_order, ""}, nil, order_book)
      assert code == :error
    end
  end

  defp empty_order_book() do
    %Exchange.OrderBook{
      name: :AUXLND,
      currency: :GBP,
      buy: %{},
      sell: %{},
      order_ids: Map.new(),
      completed_trades: [],
      ask_min: 99_999,
      bid_max: 1,
      max_price: 100_000,
      min_price: 0
    }
  end
  defp sample_order(%{size: z, price: p, side: s}) do
    %Order{
      type: :limit,
      order_id: "9",
      trader_id: "test_user_1",
      side: s,
      initial_size: z,
      size: z,
      price: p
    }
  end

  defp sample_expiring_order(%{size: z, price: p, side: s, id: id, exp_time: t}) do
    %Order{
      type: :limit,
      order_id: id,
      trader_id: "test_user_1",
      side: s,
      initial_size: z,
      size: z,
      price: p,
      exp_time: t
    }
  end

  defp sample_order_book(ticker) do
    buy_book =
      [
        %Order{
          type: :limit,
          order_id: "4",
          trader_id: "alchemist",
          side: :buy,
          initial_size: 250,
          size: 250,
          price: 4000
        },
        %Order{
          type: :limit,
          order_id: "6",
          trader_id: "alchemist",
          side: :buy,
          initial_size: 500,
          size: 500,
          price: 4000
        },
        %Order{
          type: :limit,
          order_id: "2",
          trader_id: "alchemist",
          side: :buy,
          initial_size: 750,
          size: 750,
          price: 3970
        },
        %Order{
          type: :limit,
          order_id: "7",
          trader_id: "alchemist",
          side: :buy,
          initial_size: 150,
          size: 150,
          price: 3960
        }
      ] |> Enum.map(&%{&1 | acknowledged_at: :os.system_time(:nanosecond)})

    sell_book =
      [
        %Order{
          type: :limit,
          order_id: "1",
          trader_id: "alchemist",
          side: :sell,
          initial_size: 750,
          size: 750,
          price: 4010
        },
        %Order{
          type: :limit,
          order_id: "5",
          trader_id: "alchemist",
          side: :sell,
          initial_size: 500,
          size: 500,
          price: 4010
        },
        %Order{
          type: :limit,
          order_id: "8",
          trader_id: "alchemist",
          side: :sell,
          initial_size: 750,
          size: 750,
          price: 4010
        },
        %Order{
          type: :limit,
          order_id: "3",
          trader_id: "alchemist",
          side: :sell,
          initial_size: 250,
          size: 250,
          price: 4020
        }
      ] |> Enum.map(&%{&1 | acknowledged_at: :os.system_time(:nanosecond)})

    order_book = %Exchange.OrderBook{
      name: ticker,
      currency: :GBP,
      buy: %{},
      sell: %{},
      order_ids: Map.new(),
      completed_trades: [],
      ask_min: 99_999,
      bid_max: 1000,
      max_price: 100_000,
      min_price: 1000
    }

    (buy_book ++ sell_book) |> Enum.reduce(order_book, fn order, order_book ->
      Exchange.OrderBook.price_time_match(order_book, order)
    end)
  end

end
