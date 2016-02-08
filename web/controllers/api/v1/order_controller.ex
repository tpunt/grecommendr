defmodule GameRecommender.Api.V1.OrderController do
  use GameRecommender.Web, :controller

  alias GameRecommender.Api.V1.Order

  def index(conn, params) do
    orders = Order.fetch_orders(params)

    render(conn, "index.json", orders: orders)
  end

  def show(conn, %{"id" => order_id}) do
    order = Order.fetch_order(order_id)

    render(conn, "show.json", order: order)
  end
end
