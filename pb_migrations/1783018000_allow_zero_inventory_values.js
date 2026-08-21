/// <reference path="../pb_data/types.d.ts" />

// PocketBase treats zero as empty when a number field is marked required.
// Inventory counters must allow zero, otherwise an out-of-stock product cannot
// be edited even when only an unrelated field (such as its name) changes.
migrate((app) => {
  const products = app.findCollectionByNameOrId("products")

  for (const name of ["stockQty", "lowStockThreshold", "damagedQty"]) {
    const field = products.fields.getByName(name)
    if (field) field.required = false
  }

  app.save(products)
}, (app) => {
  const products = app.findCollectionByNameOrId("products")

  for (const name of ["stockQty", "lowStockThreshold", "damagedQty"]) {
    const field = products.fields.getByName(name)
    if (field) field.required = true
  }

  app.save(products)
})
