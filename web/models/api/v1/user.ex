defmodule GameRecommender.Api.V1.User do
  use GameRecommender.Web, :model

  def fetch_users(params) do
    cypher_query =
      case params do
        %{"username" => username} ->
          """
            MATCH (user:User {username: '#{username}'})
            RETURN user
          """
        _ ->
          """
            MATCH (users:User)
            RETURN users
          """
      end

    users = Neo4j.query!(Neo4j.conn, cypher_query)

    case users do
      [] ->
        raise "User not found"
      [%{"user" => user_info}] -> # normalise struct keys to "users"
        [%{"users" => user_info}]
      users ->
        users
    end
  end

  def fetch_user(user_id) do
    cypher_query = """
      MATCH (user:User {userId: #{user_id}})
      RETURN user
    """

    user = Neo4j.query!(Neo4j.conn, cypher_query)

    case user do
      [] ->
        raise "User not found"
      [%{"user" => user_info}] -> # normalise the name (simpler solution...)
        %{"users" => user_info}
    end
  end
end
