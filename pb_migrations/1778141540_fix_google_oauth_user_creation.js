/// <reference path="../pb_data/types.d.ts" />
migrate((app) => {
  const collection = app.findCollectionByNameOrId("_pb_users_auth_")

  unmarshal({
    "createRule": "@request.auth.id = \"\" || @request.auth.role = \"admin\"",
    "listRule": "id = @request.auth.id || adminId = @request.auth.id || @request.auth.role = \"admin\"",
    "viewRule": "id = @request.auth.id || adminId = @request.auth.id || @request.auth.role = \"admin\"",
    "updateRule": "id = @request.auth.id || adminId = @request.auth.id || @request.auth.role = \"admin\"",
    "oauth2": {
      "mappedFields": {
        "id": "",
        "name": "name",
        "username": "",
        "avatarURL": "avatar"
      }
    }
  }, collection)

  return app.save(collection)
}, (app) => {
  const collection = app.findCollectionByNameOrId("_pb_users_auth_")

  unmarshal({
    "createRule": "@request.auth.id != \"\"\n",
    "listRule": "id = @request.auth.id\n",
    "viewRule": "id = @request.auth.id\n",
    "updateRule": "id = @request.auth.id\n",
    "oauth2": {
      "mappedFields": {
        "id": "",
        "name": "name",
        "username": "adminId",
        "avatarURL": "avatar"
      }
    }
  }, collection)

  return app.save(collection)
})
