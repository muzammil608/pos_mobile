/// <reference path="../pb_data/types.d.ts" />

migrate((app) => {
  const hasField = (collection, name) => {
    try {
      return !!collection.fields.getByName(name)
    } catch (_) {
      return false
    }
  }

  let products = null
  try {
    products = app.findCollectionByNameOrId("products")
  } catch (_) {
    products = null
  }
  if (!products) return

  if (!hasField(products, "purchasePrice")) {
    products.fields.add(
      new NumberField({ name: "purchasePrice", min: 0 }),
    )
    app.save(products)
  }

  for (const record of app.findRecordsByFilter("products", "", "created", 0, 0)) {
    const current = record.get("purchasePrice")
    if (current === null || current === undefined || current === "") {
      const legacyCost = Number(record.get("cost_price") || record.get("costPrice") || 0)
      record.set("purchasePrice", legacyCost)
      app.save(record)
    }
  }
}, (app) => {
  const hasField = (collection, name) => {
    try {
      return !!collection.fields.getByName(name)
    } catch (_) {
      return false
    }
  }

  let products = null
  try {
    products = app.findCollectionByNameOrId("products")
  } catch (_) {
    products = null
  }
  if (!products) return

  if (hasField(products, "purchasePrice")) {
    products.fields.removeByName("purchasePrice")
    app.save(products)
  }
})
