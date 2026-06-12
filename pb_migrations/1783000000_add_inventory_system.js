/// <reference path="../pb_data/types.d.ts" />

migrate((app) => {
  const safeFindCollection = (nameOrId) => {
    try {
      return app.findCollectionByNameOrId(nameOrId)
    } catch (_) {
      return null
    }
  }

  const products = safeFindCollection("products")
  if (products) {
    for (const field of [
      new NumberField({ name: "stockQty", onlyInt: true, min: 0 }),
      new NumberField({ name: "lowStockThreshold", onlyInt: true, min: 0 }),
      new NumberField({ name: "damagedQty", onlyInt: true, min: 0 }),
      new TextField({ name: "barcode", max: 255 }),
    ]) {
      if (!products.fields.getByName(field.name)) {
        products.fields.add(field)
      }
    }
    app.save(products)

    for (const record of app.findRecordsByFilter("products", "", "created", 0, 0)) {
      if (record.get("stockQty") === null || record.get("stockQty") === undefined) {
        record.set("stockQty", 0)
      }
      if (record.get("lowStockThreshold") === null || record.get("lowStockThreshold") === undefined) {
        record.set("lowStockThreshold", 5)
      }
      if (record.get("damagedQty") === null || record.get("damagedQty") === undefined) {
        record.set("damagedQty", 0)
      }
      if (!record.getString("barcode")) {
        record.set("barcode", "")
      }
      app.save(record)
    }

    products.fields.add(
      new NumberField({ name: "stockQty", required: true, onlyInt: true, min: 0 }),
      new NumberField({ name: "lowStockThreshold", required: true, onlyInt: true, min: 0 }),
      new NumberField({ name: "damagedQty", required: true, onlyInt: true, min: 0 }),
    )
    app.save(products)
  }

  let tx = safeFindCollection("inventory_transactions")
  if (!tx) {
    tx = new Collection({ type: "base", name: "inventory_transactions" })
    app.save(tx)
  }

  tx.fields.add(
    new TextField({ name: "ownerId", required: true, max: 255 }),
    new TextField({ name: "productId", required: true, max: 255 }),
    new TextField({ name: "productName", required: true, max: 255 }),
    new SelectField({
      name: "type",
      required: true,
      values: ["sale", "restock", "damage", "adjustment"],
      maxSelect: 1,
    }),
    new NumberField({ name: "quantity", required: true, onlyInt: true, min: 0 }),
    new NumberField({ name: "previousStock", required: true, onlyInt: true, min: 0 }),
    new NumberField({ name: "newStock", required: true, onlyInt: true, min: 0 }),
    new TextField({ name: "orderId", max: 255 }),
    new TextField({ name: "note", max: 1024 }),
    new AutodateField({ name: "created", onCreate: true }),
    new AutodateField({ name: "updated", onCreate: true, onUpdate: true }),
  )
  tx.listRule = 'ownerId = @request.auth.id || ownerId = @request.auth.adminId || @request.auth.role = "admin"'
  tx.viewRule = tx.listRule
  tx.createRule = '@request.auth.id != ""'
  tx.updateRule = tx.listRule
  tx.deleteRule = 'ownerId = @request.auth.id || @request.auth.role = "admin"'
  tx.indexes = [
    "CREATE INDEX idx_inv_tx_owner_created ON inventory_transactions (ownerId, created)",
    "CREATE INDEX idx_inv_tx_owner_product ON inventory_transactions (ownerId, productId)",
  ]
  app.save(tx)
}, (app) => {
  let tx = null
  try {
    tx = app.findCollectionByNameOrId("inventory_transactions")
  } catch (_) {
    tx = null
  }
  if (tx) {
    app.delete(tx)
  }
})
