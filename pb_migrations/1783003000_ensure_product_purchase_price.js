/// <reference path="../pb_data/types.d.ts" />

migrate((app) => {
  const safeFindCollection = (nameOrId) => {
    try {
      return app.findCollectionByNameOrId(nameOrId)
    } catch (_) {
      return null
    }
  }

  const hasField = (collection, name) => {
    try {
      return !!collection.fields.getByName(name)
    } catch (_) {
      return false
    }
  }

  const products = safeFindCollection("products")
  if (!products || hasField(products, "purchasePrice")) return

  products.fields.add(
    new NumberField({ name: "purchasePrice", min: 0 }),
  )
  app.save(products)
}, (app) => {
  // Intentionally no-op. The previous migration owns the rollback.
})
