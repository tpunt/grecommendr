defmodule GameRecommender.Api.V1.GameView do
  use GameRecommender.Web, :view

  def render("index.json", %{games: games}) do
    %{games: render_many(games, GameRecommender.Api.V1.GameView, "game.json")}
  end

  def render("show.json", %{game: game}) do
    %{game: render_one(game, GameRecommender.Api.V1.GameView, "game.json")}
  end

  def render("game.json", %{game: game}) do
    case game do # singular/plural problems...
      %{"games" => game} ->
        game = game
      %{"game" => game} ->
        game = game
    end
    %{gameId: game["gameId"],
      gameName: game["gameName"],
      preorderCount: game["preorderCount"],
      purchaseCount: game["purchaseCount"],
      demoDownloadCount: game["demoDownloadCount"],
      releaseDate: game["releaseDate"],
      genre: game["genre"],
      tags: game["tags"]}
  end
end
