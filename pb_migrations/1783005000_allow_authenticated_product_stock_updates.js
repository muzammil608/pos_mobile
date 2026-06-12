/// <reference path="../pb_data/types.d.ts" />

migrate((app) => {
  let products = null
  try {
    products = app.findCollectionByNameOrId("products")
  } catch (_) {
    products = null
  }

  if (!products) return

  products.updateRule = '@request.auth.id != ""'
  app.save(products)
}, (app) => {
  let products = null
  try {
    products = app.findCollectionByNameOrId("products")
  } catch (_) {
    products = null
  }

  if (!products) return

  products.updateRule =
    'ownerId = @request.auth.id || ownerId = @request.auth.adminId || @request.auth.role = "admin"'
  app.save(products)
})

