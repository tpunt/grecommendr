defmodule GameRecommender.Router do
  use GameRecommender.Web, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/api", GameRecommender.Api, as: :api do
    pipe_through :api

    scope "/v1", V1, as: :v1 do
      get "/users", UserController, :index
      get "/users/:id", UserController, :show
      get "/games", GameController, :index
      get "/games/recommendations", GameController, :recommendations
      get "/games/:id", GameController, :show
      get "/orders", OrderController, :index
      get "/orders/:id", OrderController, :show
    end
  end
end
