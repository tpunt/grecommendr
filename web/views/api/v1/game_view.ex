defmodule GameRecommender.Api.V1.GameView do
  use GameRecommender.Web, :view

  def render("index.json", %{games: games}) do
    %{games: render_many(games, GameRecommender.Api.V1.GameView, "game.json")}
  end

  def render("show.json", %{game: game}) do
    %{game: render_one(game, GameRecommender.Api.V1.GameView, "game.json")}
  end

  def render("game.json", %{game: game_info}) do
    %{"game" => game} = game_info

    %{gameId: game["gameId"],
      gameName: game["gameName"],
      preorderCount: game["preorderCount"],
      purchaseCount: game["purchaseCount"],
      releaseDate: game["releaseDate"],
      averageRating: game["averageRating"],
      genre: game["genre"],
      tags: game["tags"]}
  end
end
