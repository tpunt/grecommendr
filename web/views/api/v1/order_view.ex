defmodule GameRecommender.Api.V1.OrderView do
  use GameRecommender.Web, :view

  def render("index.json", %{orders: orders}) do
    %{orders: render_many(orders, GameRecommender.Api.V1.OrderView, "order.json")}
  end

  def render("show.json", %{order: order}) do
    %{order: render_one(order, GameRecommender.Api.V1.OrderView, "order.json")}
  end

  def render("order.json", %{order: %{"orders" => order}}) do
    %{orderId: order["orderId"],
      orderPrice: order["orderPrice"],
      orderDate: order["orderDate"]}
  end
end
