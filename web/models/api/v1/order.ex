defmodule GameRecommender.Api.V1.Order do
  use GameRecommender.Web, :model

  def fetch_orders(params) do
    cypher_query =
      case params do
        %{"user_id" => user_id} ->
          """
            MATCH (User {userId: #{user_id}})-[:PURCHASED]->(orders:Order)
            RETURN orders
          """
        _ ->
          """
            MATCH (orders:Order)
            RETURN orders
          """
      end

    orders = Neo4j.query!(Neo4j.conn, cypher_query)

    case orders do
      [%{"order" => order_info}] -> # normalise struct keys to "orders"
        [%{"orders" => order_info}]
      orders ->
        orders
    end
  end

  def fetch_order(order_id) do
    cypher_query = """
      MATCH (order:Order {orderId: #{order_id}})
      RETURN order
    """

    order = Neo4j.query!(Neo4j.conn, cypher_query)

    case order do
      [] ->
        raise "Order not found"
      [%{"order" => order_info}] -> # normalise the name (simpler solution...)
        %{"orders" => order_info}
    end
  end
end
