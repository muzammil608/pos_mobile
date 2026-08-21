/// <reference path="../pb_data/types.d.ts" />

migrate((app) => {
  let products = null
  try {
    products = app.findCollectionByNameOrId("products")
  } catch (_) {
    products = null
  }

  if (!products) return

  products.listRule = 'ownerId = @request.auth.id || ownerId = @request.auth.adminId || @request.auth.role = "admin"'
  products.viewRule = products.listRule
  products.createRule = '@request.auth.id != ""'
  products.updateRule = 'ownerId = @request.auth.id || @request.auth.role = "admin"'
  products.deleteRule = products.updateRule
  app.save(products)
}, (app) => {
  let products = null
  try {
    products = app.findCollectionByNameOrId("products")
  } catch (_) {
    products = null
  }

  if (!products) return

  products.listRule = '@request.auth.id != ""'
  products.viewRule = '@request.auth.id != ""'
  products.createRule = '@request.auth.id != ""'
  products.updateRule = '@request.auth.id != ""'
  products.deleteRule = '@request.auth.id != ""'
  app.save(products)
})
