defmodule GameRecommender.Api.V1.Order do
  use GameRecommender.Web, :model

  def fetch_orders(params) do
    cypher_query =
      case params do
        %{"user_id" => user_id} ->
          """
            MATCH (User {userId: #{user_id}})-[:PURCHASED]->(order:Order)-[:CONTAINS]->(game:Game)
            RETURN order, game.gameId AS gameId
          """
        _ ->
          """
            MATCH (order:Order)-[:CONTAINS]->(game:Game)
            RETURN order, game.gameId AS gameId
          """
      end

    Neo4j.query!(Neo4j.conn, cypher_query)
    |> compact_orders
  end

  def fetch_order(order_id) do
    cypher_query = """
      MATCH (order:Order {orderId: #{order_id}})-[:CONTAINS]->(game:Game)
      RETURN order, game.gameId AS gameId
    """

    order =
      Neo4j.query!(Neo4j.conn, cypher_query)
      |> compact_orders

    case order do
      [] ->
        raise "Order not found"
      [order] ->
        order
    end
  end

  defp compact_orders(orders) do
    orders
    |> Enum.reduce([], fn (data = %{"gameId" => gid, "order" => %{"orderId" => oid}}, new_data) ->
        game = [gid]
        new_data =
          if idx = Enum.find_index(new_data, fn (new_data) -> new_data["order"]["orderId"] === oid end) do
            data = Enum.at(new_data, idx)
            games = Enum.into(data["games"], game)
            List.replace_at(new_data, idx, %{"games" => games, "order" => data["order"]})
          else
            Enum.concat(new_data, [%{"games" => game, "order" => data["order"]}])
          end
      end)
  end
end
