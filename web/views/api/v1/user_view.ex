defmodule GameRecommender.Api.V1.UserView do
  use GameRecommender.Web, :view

  def render("index.json", %{users: users}) do
    %{users: render_many(users, GameRecommender.Api.V1.UserView, "user.json")}
  end

  def render("show.json", %{user: user}) do
    %{user: render_one(user, GameRecommender.Api.V1.UserView, "user.json")}
  end

  def render("user.json", %{user: %{"users" => user}}) do
    %{username: user["username"], userId: user["userId"]}
  end
end
