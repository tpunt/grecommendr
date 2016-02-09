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
            MATCH (game:Game)
            RETURN game
          """
      end

    case Neo4j.query!(Neo4j.conn, cypher_query) do
      [] ->
        raise "No games found"
      games ->
        games
    end
  end

  def fetch_game(game_id) do
    cypher_query = """
      MATCH (game:Game {gameId: #{game_id}})
      RETURN game
    """

    case Neo4j.query!(Neo4j.conn, cypher_query) do
      [] ->
        raise "Game not found"
      [game] ->
        game
    end
  end
end
