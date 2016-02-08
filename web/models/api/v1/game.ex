defmodule GameRecommender.Api.V1.Game do
  use GameRecommender.Web, :model

  def fetch_games(params) do
    cypher_query =
      case params do
        %{"game_name" => game_name} ->
          """
            MATCH (game:Game {gameName: '#{game_name}'})
            RETURN game
          """
        _ ->
          """
            MATCH (games:Game)
            RETURN games
          """
      end

    games = Neo4j.query!(Neo4j.conn, cypher_query)

    case games do
      [] ->
        raise "User not found"
      [%{"game" => game_info}] -> # normalise struct keys to "games"
        [%{"games" => game_info}]
      games ->
        games
    end
  end

  def fetch_game(game_id) do
    cypher_query = """
      MATCH (game:Game {gameId: #{game_id}})
      RETURN game
    """

    game = Neo4j.query!(Neo4j.conn, cypher_query)

    case game do
      [] ->
        raise "Game not found"
      [%{"game" => game_info}] -> # normalise the name (simpler solution...)
        %{"games" => game_info}
    end
  end
end
