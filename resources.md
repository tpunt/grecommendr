# Exposed RESTful API Resources

## Resources List

### GET api/v1/users
Query string filtering:
 - username=.+

Example output:
```
{"users":[{"username":"user_1","userId":1},{"username":"user_2","userId":2}]}
```

### GET api/v1/users/:id
Get a specific user

Example output:
```
{"user":{"username":"user_1","userId":1}}
```

### GET api/v1/games
Query string filtering:
 - game_name=.+

Example output:
```
{"games":[{"tags":["fps","action","shooter","multiplayer"],"releaseDate":"2011-11-05","purchaseCount":6666,"preorderCount":5124,"genre":"action","gameName":"Call of Duty: Modern Warfare 2","gameId":1,"demoDownloadCount":153},{"tags":["fps","action","shooter","multiplayer","zombies"],"releaseDate":"2015-11-06","purchaseCount":8475,"preorderCount":1999,"genre":"action","gameName":"Call of Duty: Black Ops III","gameId":2,"demoDownloadCount":235}]}
```

### GET api/v1/games/:id
Get a specific game

Example output:
```
{"game":{"tags":["fps","action","shooter","multiplayer"],"releaseDate":"2011-11-05","purchaseCount":6666,"preorderCount":5124,"genre":"action","gameName":"Call of Duty: Modern Warfare 2","gameId":1,"demoDownloadCount":153}}
```

### GET api/v1/games/recommendations
Query string filtering:
 - user_id=[0-9]+
 - type=(for_user|most_popular|top_rated|upcoming|recently_released)

Provide a `user_id` to tailor the results to a particular user.

The type defaults to `for_user`, and that requires a `user_id` to
be specified.

All example outputs follow the same formatting as the **api/v1/games** resource.

### GET api/v1/orders
Query string filtering:
 - user_id=[0-9]+

Example output:
```
{"orders":[{"orderPrice":29.99,"orderId":3,"orderDate":1315526400},{"orderPrice":21.99,"orderId":4,"orderDate":1451795800}]}
```

### GET api/v1/orders/:id
Get a specific order

Example output:
```
{"order":{"orderPrice":15.99,"orderId":1,"orderDate":1293840000}}
```
