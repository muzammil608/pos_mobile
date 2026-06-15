/// <reference path="../pb_data/types.d.ts" />

migrate((app) => {
  const products = app.findRecordsByFilter(
    "products",
    'ownerId != ""',
    "created",
    1,
    0,
  )
  if (products.length === 0) return

  const templateOwnerId = products[0].getString("ownerId")
  const templates = app.findRecordsByFilter(
    "products",
    `ownerId = "${templateOwnerId}"`,
    "created",
    0,
    0,
  )
  if (templates.length === 0) return

  const productsCollection = app.findCollectionByNameOrId("products")
  const admins = app.findRecordsByFilter("users", 'role = "admin"', "created", 0, 0)

  for (const admin of admins) {
    const adminId = admin.id
    const existing = app.findRecordsByFilter(
      "products",
      `ownerId = "${adminId}"`,
      "created",
      1,
      0,
    )
    if (existing.length > 0) continue

    for (const template of templates) {
      const product = new Record(productsCollection)
      product.set("ownerId", adminId)
      product.set("model_code", template.getString("model_code"))
      product.set("brand", template.getString("brand"))
      product.set("item_name", template.getString("item_name"))
      product.set("quality_tier", template.getString("quality_tier"))
      product.set("wholesale_rate", template.getFloat("wholesale_rate"))
      product.set("retail_rate", template.getFloat("retail_rate"))
      product.set("category", template.getString("category"))
      product.set("backup_image_url", template.getString("backup_image_url"))
      product.set("stockQty", template.getInt("stockQty"))
      product.set("lowStockThreshold", template.getInt("lowStockThreshold"))
      product.set("damagedQty", template.getInt("damagedQty"))
      product.set("barcode", template.getString("barcode"))
      app.save(product)
    }
  }
}, (app) => {
  // Product copies may already have been edited or sold, so rollback is a no-op.
})
