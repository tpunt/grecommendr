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
    MATCH (user:User {userId: #{user_id}})-[game_rating:RATES]->(game:Game)
    RETURN user, game_rating, game
    """

    cypher_query2 = """
    MATCH (User {userId: #{user_id}})-[:RATES]->(Game)<-[:RATES]-(u:User)
    WITH collect(u.userId) AS ids
    MATCH (user:User)-[game_rating:RATES]->(game:Game)
    WHERE user.userId IN ids
    RETURN user, game, game_rating
    """

    [user_a] =
      Neo4j.query!(Neo4j.conn, cypher_query)
      |> restructure_user_game_rating_data

    owned_games_ids =
      get_user_games(user_id)
      |> Enum.map(fn (%{"game" => %{"gameId" => game_id}}) -> game_id end)

    data =
      Neo4j.query!(Neo4j.conn, cypher_query2)
      # reduce the pulled data into an easier to work with structure
      |> restructure_user_game_rating_data(user_a)
      # set the neighbourhood threshold of requiring at least 3 overlapping game ratings
      |> Enum.filter(fn (data) ->
          data.game_overlap > 0 # update to 2 later
        end)
      # remove any users who have rated the exact games only
      |> Enum.filter(fn (data) ->
          data.game_overlap !== Enum.count(data.games)
        end)
      # remove any users who have only rated games user A already owns
      |> Enum.filter(fn (data) ->
          # update this line to use the convenient game_ids property
          Enum.any?(data.games, fn (%{"game" => %{"gameId" => game_id}}) -> !Enum.member?(owned_games_ids, game_id) end)
        end)

    diff_game_ids =
      data
      # Get lists of the overlapping games that are not on user A's rating list
      |> Enum.map(fn (data) ->
          data.games
          |> Enum.map(fn (%{"game" => %{"gameId" => game_id}}) ->
              unless Enum.any?(user_a.games, fn (%{"game" => %{"gameId" => r_game_id}}) -> r_game_id === game_id end), do: game_id
            end)
          |> Enum.filter(fn (game_ids) -> game_ids !== :nil end)
        end)
      # flatten the list
      |> List.flatten
      # count the number of occurrences for each game ID
      |> Enum.reduce([], fn (game_id, new_data) ->
          if idx = Enum.find_index(new_data, fn (data) -> data.game_id === game_id end) do
            data = Enum.at(new_data, idx)
            List.replace_at(new_data, idx, update_in(data.count, &(&1 + 1)))
          else
            [%{game_id: game_id, count: 1} | new_data]
          end
        end)
      # order the game ids list by the most commonly occurring
      |> Enum.sort(fn (%{game_id: id_x, count: c_x}, %{game_id: id_y, count: c_y}) ->
          c_x > c_y
        end)
      # just retrieve the game IDs now
      |> Enum.map(fn (%{game_id: id}) -> id end)

# user_a.games
# data.games
# IO.inspect diff_game_ids

    diff_game_ids
    |> Enum.map(fn (game_id) ->
        table = %{predict_for: game_id, games: []}

        Enum.reduce(user_a.games, table, fn (%{"game" => %{"gameId" => gid1}, "rating" => rating1}, table) ->
          Enum.reduce(data.games, table, fn (%{"game" => %{"gameId" => gid2}, "rating" => rating2}, table) ->
            if gid1 === gid2 do
              if idx = Enum.find_index(table.games, fn (%{"game" => %{"gameId" => gid3}}) -> gid2 === gid3 end) do
                game = Enum.at(table.games, idx)
                List.replace_at(table.games,
                  idx,
                  %{game: game, })
                # if the game exists, update it
              else
                #insert it
              end
            else
              table
            end
          end)
        end)
      end)

    diff_game_ids
    |> Enum.map(fn (game_id) ->
        neighbour_similarities = Enum.reduce(data, [], fn (data2, new_data) ->
          if Enum.member?(data2.game_ids, game_id) do
            Enum.map(user_a.games, fn (%{"game" => %{"gameId" => gid1}, "rating" => rating1}) ->
              if idx = Enum.find_index(data2.games, fn (%{"game" => %{"gameId" => gid2}}) -> gid2 === gid1 end) do
                game = Enum.at(data2.games, idx)
                %{"game" => %{"gameId" => gid}, "rating" => rating2} = game



                # user_a = user_id
                # user_b = data2.user["user_id"]
                # game_x = gid
                # user_a_rating = rating1
                # user_b_rating = rating2
                # user_a_avg_rating = user_a.avg_game_rating
                # user_b_avg_rating = data2.avg_game_rating

                #
              end
            end)
          else
            0
          end
        end)
      end)

    # IO.inspect data
    IO.inspect ExMatrix.new_matrix(2,2)
  end

  defp sim(user_a, user_b) do
    sum1 = user_a_rating - user_a_avg_rating
    sum2 = user_b_rating - user_b_avg_rating

    (sum sum1 * sum2)
    /
    (:math.sqrt(sum1 * sum1) * :math.sqrt(sum2 * sum2))
  end

  defp pred(user_a, user_b, item_a, n) do
    (sum y - sim(user_a, user_b))
    /
    n
  end

  defp restructure_user_game_rating_data(data, user_a) do
    data
    |> Enum.reduce([], fn (data, new_data) ->
        game = %{"game" => data["game"], "rating" => data["game_rating"]["rating"]}
        game_id = data["game"]["gameId"]

        if idx = Enum.find_index(new_data, fn (new_data) -> new_data.user["userId"] === data["user"]["userId"] end) do
          data2 = Enum.at(new_data, idx)
          games = Enum.into(data2.games, [game])
          game_overlap = if Enum.any?(user_a.games, fn (%{"game" => %{"gameId" => r_game_id}}) -> r_game_id === game_id end), do: 1, else: 0

          List.replace_at(new_data,
            idx,
            %{user: data2.user,
              games: games,
              game_ids: [game_id | data2.game_ids],
              game_overlap: data2.game_overlap + game_overlap,
              avg_game_rating: (data2.avg_game_rating * data2.game_rating_count + game["rating"]) / (data2.game_rating_count + 1),
              game_rating_count: data2.game_rating_count + 1})
        else
          game_overlap = if Enum.any?(user_a.games, fn (%{"game" => %{"gameId" => r_game_id}}) -> r_game_id === game_id end), do: 1, else: 0
          Enum.concat(new_data,
            [%{user: data["user"],
              games: [game],
              game_ids: [game_id],
              game_overlap: game_overlap,
              avg_game_rating: game["rating"],
              game_rating_count: 1}])
        end
      end)
  end

  defp restructure_user_game_rating_data(data) do
    data
    |> Enum.reduce([], fn (data, new_data) ->
        game = %{"game" => data["game"], "rating" => data["game_rating"]["rating"]}
        game_id = data["game"]["gameId"]

        if idx = Enum.find_index(new_data, fn (new_data) -> new_data.user["userId"] === data["user"]["userId"] end) do
          data2 = Enum.at(new_data, idx)
          games = Enum.into(data2.games, [game])

          List.replace_at(new_data,
            idx,
            %{user: data2.user,
              games: games,
              game_ids: [game_id | data2.game_ids],
              avg_game_rating: (data2.avg_game_rating * data2.game_rating_count + game["rating"]) / (data2.game_rating_count + 1),
              game_rating_count: data2.game_rating_count + 1})
        else
          Enum.concat(new_data,
            [%{user: data["user"],
              games: [game],
              game_ids: [game_id],
              avg_game_rating: game["rating"],
              game_rating_count: 1}])
        end
      end)
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

    positive_tags =
      positive_games
      |> Enum.map(fn (%{"games" => %{"tags" => tags}}) -> tags end)
      |> List.flatten
      |> Enum.uniq_by(&(&1))

    negative_games = get_user_disliked_games user_id

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
          %{weighting: (2 * purchase_count * tag_similarity) / (purchase_count + tag_similarity),
          game: game.game}
        end)
      # sort the games according to their calculated weighting
      |> Enum.sort(fn (%{weighting: weighting_x}, %{weighting: weighting_y}) ->
          weighting_x > weighting_y
        end)
      # remove game weighting - this does not need to be exposed via the web service
      |> Enum.map(fn (game) -> game.game end)

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
