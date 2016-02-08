defmodule GameRecommender.Api.V1.GameController do
  use GameRecommender.Web, :controller

  alias GameRecommender.Api.V1.Game
  alias GameRecommender.Api.V1.GameRecommendations

  def index(conn, params) do
    games = Game.fetch_games(params)

    render(conn, "index.json", games: games)
  end

  def show(conn, params = %{"id" => id}) do
    IO.inspect params
    game = Game.fetch_game(id)

    render(conn, "show.json", game: game)
  end

  def recommendations(conn, params) do
    recommendations = GameRecommendations.recommendations(params)

    render(conn, "index.json", games: recommendations)
  end
end
