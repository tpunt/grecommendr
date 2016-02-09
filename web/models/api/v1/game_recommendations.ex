# Breadcrumbs
# 1. Look into the significance weighting formula for the most_popular resource
#    (personalised version)
# 2. Refactor the most_popular resource (personalised version)
# 3. Implement the for_user resource using the algorithm in the lecture slides
# 4. Write the report!

defmodule GameRecommender.Api.V1.GameRecommendations do
  use GameRecommender.Web, :model

  @default_recommendation_type "for_user"
  @default_time_lapse "past_year"
  @game_display_count 10 # take the top 10 games

  def recommendations(params) do
    unless Map.has_key?(params, "type") do
      params = Map.put(params, "type", @default_recommendation_type)
    end

    recommend(params)
    |> Enum.take(@game_display_count)

    # prioritise genres/tags according to what come up the most?
    # prioritise games released in the past year/have not yet been released?
    # recommended only on recent stuff?
    # avoiding recommending on stagnant user data, unless they have no recent to recommend on?

    # update DB to store download count on a per monthly basis?
    # take average monthly purchases

    # for users with no data, look at most recently released games and order them according to download counts?
    # take games from past X months and limit it to 10 displayed?

    # generic recommendations for a specific user should not include their liked/wished for games, since
    # they already know about those games, and so we are looking to introduce them to new content...
    #  |> Enum.filter(fn (%{"game" => %{"gameId" => game_id}}) ->
    #     Enum.any?(positive_games, fn (%{"game" => %{"gameId" => game_id_2}}) ->
    #       game_id === game_id_2
    #     end)
    #   end)

    # get user dislikes
    # maybe take dislikes into account if the user has never liked any game of that genre/tags
    # cancel dislikes
  end

  defp recommend(%{"user_id" => user_id, "type" => "for_user"}) do
    all_games = recommend %{"type" => "top_rated"}

    # get a list of all of the games a user has rated, along with what they have rated them
    # get a list of users who have rated the most of the same games
    # sort out a threshold to distinguish the neighbourhood - i.e. only users who have rated 5 or more of the same game
    # order these neighbourhood users? What difference will this make? variance weighting?
    # use her algorithm to calculate similarity of neighbourhood

    cypher_query = """
    MATCH (user1:User {userId: #{user_id}})-[user1_game1_rating:RATES]->(game1:Game)<-[user2_game1_rating:RATES]-(user2:User)-[user2_game2_rating:RATES]->(game2:Game)
    RETURN user1, game1, user1_game1_rating, user2, user2_game1_rating, game2, user2_game2_rating
    """

    cypher_query2 = """
    MATCH (User {userId: #{user_id}})-[:RATES]->(game:Game)
    RETURN collect(game.gameId) AS games
    """

    user_rated_games = Neo4j.query!(Neo4j.conn, cypher_query2)

    data = Neo4j.query!(Neo4j.conn, cypher_query)

    data =
      data
      # reduce the pulled data into an easier to work with structure
      |> Enum.reduce([], fn (data, new_data) ->
          user1_game1 = [%{"game" => data["game1"], "rating" => data["user1_game1_rating"]["rating"]}]
          user2_game1 = [%{"game" => data["game1"], "rating" => data["user2_game1_rating"]["rating"]}]
          user2_game2 = [%{"game" => data["game2"], "rating" => data["user2_game2_rating"]["rating"]}]
          new_data =
            if idx = Enum.find_index(new_data, fn (new_data) -> new_data.user["userId"] === data["user1"]["userId"] end) do
              # the user already exists, so update it
              data2 = Enum.at(new_data, idx)

              if Enum.find_index(data2.games, fn (game) -> game["game"]["gameId"] === data["game1"]["gameId"] end) do
                # the game already exists, so do nothing
                new_data
              else
                games = Enum.into(data2.games, user1_game1)
                #why game overlap here?
                List.replace_at(new_data, idx, %{user: data2.user, games: games, game_overlap: data2.game_overlap + 1})
              end
            else
              #why game overlap here?
              Enum.concat(new_data, [%{user: data["user1"], games: user1_game1, game_overlap: 1}])
            end

          new_data =
            if idx = Enum.find_index(new_data, fn (new_data) -> new_data.user["userId"] === data["user2"]["userId"] end) do
              # the user already exists, so update it
              data2 = Enum.at(new_data, idx)

              if Enum.find_index(data2.games, fn (game) -> game["game"]["gameId"] === data["game1"]["gameId"] end) do
                # the game already exists, so do nothing
                new_data
              else
                games = Enum.into(data2.games, user2_game1)
                List.replace_at(new_data, idx, %{user: data2.user, games: games, game_overlap: data2.game_overlap + 1})
              end
            else
              game_overlap = 1
# IO.puts "game 2 (ever) in user1 ratings?"
# IO.inspect user_rated_games
# IO.inspect data["game2"]["gameId"]
              [%{"games" => rated_games}] = user_rated_games

              if Enum.member?(rated_games, data["game2"]["gameId"]) do
                game_overlap = 2
              end

              Enum.concat(new_data, [%{user: data["user2"], games: Enum.concat(user2_game1, user2_game2), game_overlap: game_overlap}])
            end
        end)
      # set the threshold of requiring at least 3 overlapping game ratings
      |> Enum.filter(fn (data) ->
          data.game_overlap > 1 # update to 2 later
        end)
      # remove any users who have rated the exact games only (except for the user at hand)
      |> Enum.filter(fn (data) ->
          # IO.inspect data.user["userId"]
          # IO.inspect user_id
          # IO.inspect "#{data.user["userId"]}" === user_id
          !(data.game_overlap === Enum.count(data.games) && "#{data.user["userId"]}" !== user_id)
        end)
      # rank the neighbourhood in terms of items they have most in common (that are not on the user at hand's rating list)
      # |> ...

    IO.inspect data

    Enum.at(data, 0).games

    # negative_games = get_user_disliked_games user_id
    # neutral_games = get_user_neutral_games user_id
    # positive_games = get_user_liked_games user_id
    #
    # rated_games =
    #   negative_games
    #   |> Enum.concat neutral_games
    #   |> Enum.concat positive_games
    #
    # games_owned = get_user_games user_id
    #
    # all_games
    # # remove all games the user has already purchased
    # |> Enum.filter(fn (%{"game" => %{"gameId" => game_id}}) ->
    #     !Enum.any?(games_owned, fn (%{"game" => %{"gameId" => game_id_2}}) ->
    #       game_id === game_id_2
    #     end)
    #   end)
    # # remove all games the user has rated (since they already know of those games)
    # |> Enum.filter(fn (%{"game" => %{"gameId" => game_id}}) ->
    #     !Enum.any?(rated_games, fn (%{"games" => %{"gameId" => game_id_2}}) ->
    #       game_id === game_id_2
    #     end)
    #   end)
  end

  defp recommend(%{"user_id" => user_id, "type" => "top_rated"}) do
    all_games = recommend %{"type" => "top_rated"}

    negative_games = get_user_disliked_games user_id
    games_owned = get_user_games user_id

    all_games
    # remove all games the user has already purchased
    |> Enum.filter(fn (%{"game" => %{"gameId" => game_id}}) ->
        !Enum.any?(games_owned, fn (%{"game" => %{"gameId" => game_id_2}}) ->
          game_id === game_id_2
        end)
      end)
    # remove all games the user has disliked
    |> Enum.filter(fn (%{"game" => %{"gameId" => game_id}}) ->
        !Enum.any?(negative_games, fn (%{"games" => %{"gameId" => game_id_2}}) ->
          game_id === game_id_2
        end)
      end)
  end

  defp recommend(%{"type" => "top_rated"}) do
    all_games = get_all_games

    {total_rating, total_rating_count} =
      Enum.reduce(all_games,
        {0, 0},
        fn(%{"game" => %{"averageRating" => avg, "ratingCount" => count}}, {total_rating, total_count}) ->
          {total_rating + count * avg, total_count + count}
        end)

    total_rating_average = Float.round(total_rating / total_rating_count, 2)

    all_games
    # calculate the weighting according to the Bayesian formula for each game
    |> Enum.map(fn (game = %{"game" => %{"averageRating" => game_rating_average, "ratingCount" => game_rating_count}}) ->
        %{weighting:
            (total_rating_count * total_rating_average + game_rating_count * game_rating_average)
            / (total_rating_count + game_rating_count),
          game: game}
      end)
    # sort according to which has the biggest weighting
    |> Enum.sort(fn (%{weighting: weighting_x}, %{weighting: weighting_y}) ->
      weighting_x > weighting_y
    end)
    # only return the games (not their calculated weighting)
    |> Enum.map(fn (%{game: game}) -> game end)
  end

  defp recommend(%{"user_id" => user_id, "type" => "most_popular", "time_lapse" => time_lapse}) do
    top_games = recommend(%{"type" => "most_popular", "time_lapse" => time_lapse})

    positive_games =
      (get_user_wish_list user_id)
      |> Enum.concat(get_user_liked_games user_id)
      |> Enum.uniq_by(fn(%{"games" => %{"gameId" => game_id}}) -> game_id end)

    # positive_genres =
    #   positive_games
    #   |> Enum.map(fn (%{"games" => %{"genre" => genre}}) -> genre end)
    #   |> Enum.uniq_by(&(&1))

    positive_tags =
      positive_games
      |> Enum.map(fn (%{"games" => %{"tags" => tags}}) -> tags end)
      |> List.flatten
      |> Enum.uniq_by(&(&1))

    negative_games = get_user_disliked_games user_id
    #
    # negative_genres =
    #   negative_games
    #   |> Enum.map(fn (%{"games" => %{"genre" => genre}}) -> genre end)
    #   |> Enum.uniq_by(&(&1))
    #
    # negative_tags =
    #   negative_games
    #   |> Enum.map(fn (%{"games" => %{"tags" => tags}}) -> tags end)
    #   |> List.flatten
    #   |> Enum.uniq_by(&(&1))

    games_owned = get_user_games user_id

    # tailored_games =
      top_games
      # remove all games the user has already purchased
      |> Enum.filter(fn (%{"game" => %{"gameId" => game_id}}) ->
          !Enum.any?(games_owned, fn (%{"game" => %{"gameId" => game_id_2}}) ->
            game_id === game_id_2
          end)
        end)
      # remove all games the user has disliked
      |> Enum.filter(fn (%{"game" => %{"gameId" => game_id}}) ->
          !Enum.any?(negative_games, fn (%{"games" => %{"gameId" => game_id_2}}) ->
            game_id === game_id_2
          end)
        end)
      # get the number of co-rated tags for every game from the tags fo games on a user's likes and wish list
      |> Enum.map(fn (game = %{"game" => %{"tags" => tags}}) ->
          combined = Enum.concat(tags, positive_tags)
          %{tag_similarity: Enum.count(combined) - Enum.count(Enum.uniq(combined)),
          game: game}
        end)
      # calculate what weighting each game will have from tag similarity an purchase count
      |> Enum.map(fn (game = %{tag_similarity: tag_similarity, game: %{"game" => %{"purchaseCount" => purchase_count}}}) ->
          %{weighting: purchase_count * 0.7 + tag_similarity * 0.3,
          game: game.game}
        end)
      # sort the games according to their calculated weighting
      |> Enum.sort(fn (%{weighting: weighting_x}, %{weighting: weighting_y}) ->
          weighting_x > weighting_y
        end)
      # remove game weighting - this does not need to be exposed via the web service
      |> Enum.map(fn (game) -> game.game end)

    # weighting: (2 * download_count * tag_similarity) / (download_count + tag_similarity)

    # sorted =
    #   tailored_games
    #   |> Enum.sort(fn (%{game: %{"game" => %{"tags" => tags_x}}}, %{game: %{"game" => %{"tags" => tags_y}}}) ->
    #       Enum.uniq(Enum.concat(tags_x, positive_tags)) < Enum.uniq(Enum.concat(tags_y, positive_tags))
    #     end)

    # sorted
  end

  defp recommend(%{"type" => "most_popular", "time_lapse" => time_lapse}) do
    {year, month, day} = Chronos.today

    epoch_time =
      cond do
        time_lapse === "past_year" ->
          Chronos.epoch_time({year - 1, month, day})
        time_lapse === "past_month" ->
          Chronos.epoch_time({year, month - 1, day})
        time_lapse === "past_day" ->
          Chronos.epoch_time({year, month, day - 1})
      end

    cypher_query = """
      MATCH (game:Game)<-[:CONTAINS]-(order:Order)
      WHERE order.orderDate >= #{epoch_time}
      RETURN game, count(*)
    """

    Neo4j.query!(Neo4j.conn, cypher_query)
    |> Enum.sort(fn (x, y) ->
      %{"count(*)" => purchase_count_x} = x
      %{"count(*)" => purchase_count_y} = y
      purchase_count_x > purchase_count_y
    end)
  end

  defp recommend(params = %{"type" => "most_popular"}) do
    recommend(Enum.into(params, %{"time_lapse" => @default_time_lapse}))
  end

  # duplicated logic from Game.fetch_games
  defp get_all_games() do
    cypher_query = """
      MATCH (game:Game)
      RETURN game
    """

    Neo4j.query!(Neo4j.conn, cypher_query)
  end

  defp get_user_games(user_id) do
    cypher_query = """
      MATCH (user:User {userId: #{user_id}})-[:PURCHASED]->(Order)-[:CONTAINS]->(game:Game)
      RETURN game
    """

    Neo4j.query!(Neo4j.conn, cypher_query)
  end

  defp get_user_wish_list(user_id) do
    cypher_query = """
      MATCH (user:User {userId: #{user_id}})-[:WISHES_FOR]->(game:Game)
      RETURN games
    """

    Neo4j.query!(Neo4j.conn, cypher_query)
  end

  defp get_user_liked_games(user_id) do
    cypher_query = """
      MATCH (user:User {userId: #{user_id}})-[r:RATES]->(game:Game)
      WHERE r.rating > 3
      RETURN games
    """

    Neo4j.query!(Neo4j.conn, cypher_query)
  end

  defp get_user_neutral_games(user_id) do
    cypher_query = """
      MATCH (user:User {userId: #{user_id}})-[r:RATES]->(game:Game)
      WHERE r.rating = 3
      RETURN games
    """

    Neo4j.query!(Neo4j.conn, cypher_query)
  end

  defp get_user_disliked_games(user_id) do
    cypher_query = """
      MATCH (user:User {userId: #{user_id}})-[r:RATES]->(game:Game)
      WHERE r.rating < 3
      RETURN games
    """

    Neo4j.query!(Neo4j.conn, cypher_query)
  end
end
