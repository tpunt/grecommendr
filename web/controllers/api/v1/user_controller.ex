defmodule GameRecommender.Api.V1.UserController do
  use GameRecommender.Web, :controller

  alias GameRecommender.Api.V1.User

  def index(conn, params) do
    users = User.fetch_users(params)

    render(conn, "index.json", users: users)
  end

  def show(conn, %{"id" => user_id}) do
    user = User.fetch_user(user_id)

    render(conn, "show.json", user: user)
  end
end
