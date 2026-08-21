/// <reference path="../pb_data/types.d.ts" />
migrate((app) => {
  const users = app.findCollectionByNameOrId("users")
  users.fields.add(
    new JSONField({ name: "posHeaderSlides" }),
  )

  return app.save(users)
}, (app) => {
  const users = app.findCollectionByNameOrId("users")
  users.fields.removeByName("posHeaderSlides")

  return app.save(users)
})
