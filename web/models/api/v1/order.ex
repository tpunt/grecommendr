defmodule GameRecommender.Api.V1.Order do
  use GameRecommender.Web, :model

  def fetch_orders(params) do
    cypher_query =
      case params do
        %{"user_id" => user_id} ->
          """
            MATCH (User {userId: #{user_id}})-[:PURCHASED]->(order:Order)-[:CONTAINS]->(game:Game)
            RETURN order, collect(game.gameId) AS games
          """
        _ ->
          """
            MATCH (order:Order)-[:CONTAINS]->(game:Game)
            RETURN order, collect(game.gameId) AS games
          """
      end

    case Neo4j.query!(Neo4j.conn, cypher_query) do
      [] ->
        raise "No orders found"
      order ->
        order
    end
  end

  def fetch_order(order_id) do
    cypher_query = """
      MATCH (order:Order {orderId: #{order_id}})-[:CONTAINS]->(game:Game)
      RETURN order, collect(game.gameId) AS games
    """

    case Neo4j.query!(Neo4j.conn, cypher_query) do
      [] ->
        raise "Order not found"
      [order] ->
        order
    end
  end
end
