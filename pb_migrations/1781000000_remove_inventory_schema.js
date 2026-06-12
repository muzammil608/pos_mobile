/// <reference path="../pb_data/types.d.ts" />

migrate((app) => {
  try {
    const products = app.findCollectionByNameOrId("products")
    const adminUsers = app.findRecordsByFilter("users", 'role = "admin"', "created", 1, 0)
    const allUsers = app.findRecordsByFilter("users", "", "created", 1, 0)
    const fallbackOwnerId = adminUsers.length > 0
      ? adminUsers[0].id
      : (allUsers.length > 0 ? allUsers[0].id : "legacy-owner")

    const categoryNamesById = {}
    try {
      for (const category of app.findRecordsByFilter("categories", "", "name", 0, 0)) {
        categoryNamesById[category.id] = category.getString("name") || "Other"
      }
    } catch (_) {}

    try {
      products.fields.add(
        new NumberField({ name: "price", required: true, min: 0 }),
        new TextField({ name: "category", required: true, max: 120 }),
        new NumberField({ name: "iconCodePoint", onlyInt: true }),
        new TextField({ name: "imageUrl", max: 1024 }),
        new TextField({ name: "ownerId", required: true, max: 255 }),
      )
      app.save(products)
    } catch (_) {}

    try {
      for (const record of app.findRecordsByFilter("products", "", "created", 0, 0)) {
        const sellingPrice = Number(record.get("selling_price") || 0)
        const categoryId = record.getString("category_id")
        record.set("price", sellingPrice)
        record.set("category", categoryNamesById[categoryId] || "Other")
        record.set("ownerId", fallbackOwnerId)
        record.set("imageUrl", record.getString("imageUrl") || "")
        app.save(record)
      }
    } catch (_) {}

    for (const fieldName of [
      "sku",
      "barcode",
      "category_id",
      "unit",
      "cost_price",
      "selling_price",
      "low_stock_threshold",
      "is_active",
    ]) {
      try {
        products.fields.removeByName(fieldName)
      } catch (_) {}
    }

    try {
      products.listRule = '@request.auth.id != ""'
      products.viewRule = '@request.auth.id != ""'
      products.createRule = '@request.auth.id != ""'
      products.updateRule = '@request.auth.id != ""'
      products.deleteRule = '@request.auth.id != ""'
      products.indexes = [
        "CREATE INDEX idx_products_owner_name ON products (ownerId, name)",
        "CREATE INDEX idx_products_owner_category ON products (ownerId, category)",
      ]
      app.save(products)
    } catch (_) {}

    for (const name of [
      "purchase_order_items",
      "purchase_orders",
      "stock_movements",
      "inventory",
      "product_variants",
      "suppliers",
      "locations",
      "categories",
    ]) {
      try {
        const collection = app.findCollectionByNameOrId(name)
        if (collection) {
          app.delete(collection)
        }
      } catch (_) {}
    }
  } catch (e) {
    console.log("Migration 1781000000 skipped/partially applied: " + e);
  }
}, (app) => {
  // Inventory rollback is intentionally one-way here.
})
