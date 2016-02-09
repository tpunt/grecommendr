defmodule GameRecommender.Api.V1.User do
  use GameRecommender.Web, :model

  def fetch_users(params) do
    cypher_query =
      case params do
        %{"username" => username} ->
          """
            MATCH (user:User {username: '#{username}'})-[:FRIENDS_WITH]->(user2:User)
            RETURN user, collect(user2.userId)
          """
        _ ->
          """
          MATCH (user:User)-[:FRIENDS_WITH]->(user2:User)
          RETURN user, collect(user2.userId) AS friends
          """
      end

    case Neo4j.query!(Neo4j.conn, cypher_query) do
      [] ->
        raise "No users found"
      users ->
        users
    end
  end

  def fetch_user(user_id) do
    cypher_query = """
      MATCH (user:User {userId: #{user_id}})-[:FRIENDS_WITH]->(user2:User)
      RETURN user, collect(user2.userId) AS friends
    """

    case Neo4j.query!(Neo4j.conn, cypher_query) do
      [] ->
        raise "User not found"
      [user] ->
        user
    end
  end
end
