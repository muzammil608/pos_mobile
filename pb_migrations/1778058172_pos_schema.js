migrate((app) => {
  const users = app.findCollectionByNameOrId("users")
  users.fields.add(
    new SelectField({
      name: "role",
      required: true,
      values: ["admin", "cashier", "kitchen"],
      maxSelect: 1,
    }),
    new TextField({ name: "adminId", max: 255 }),
    new BoolField({ name: "isActive" }),
    new TextField({ name: "photoUrl", max: 1024 }),
    new TextField({ name: "createdBy", max: 255 }),
    new DateField({ name: "lastLoginAt" }),
    new DateField({ name: "deletedAt" }),
  )
  users.listRule = 'id = @request.auth.id || adminId = @request.auth.id || @request.auth.role = "admin"'
  users.viewRule = users.listRule
  users.createRule = ""
  users.updateRule = 'id = @request.auth.id || adminId = @request.auth.id || @request.auth.role = "admin"'
  users.deleteRule = null
  app.save(users)

  const products = new Collection({
    id: "pbc_4092854851",
    type: "base",
    name: "products",
  })
  app.save(products)
  products.fields.add(
    new TextField({ name: "name", required: true, max: 255 }),
    new NumberField({ name: "price", required: true, min: 0 }),
    new TextField({ name: "category", required: true, max: 120 }),
    new NumberField({ name: "iconCodePoint", onlyInt: true }),
    new FileField({
      name: "image",
      maxSelect: 1,
      mimeTypes: ["image/jpeg", "image/png", "image/webp", "image/gif"],
    }),
    new TextField({ name: "imageUrl", max: 1024 }),
    new TextField({ name: "ownerId", required: true, max: 255 }),
    new AutodateField({ name: "created", onCreate: true }),
    new AutodateField({ name: "updated", onCreate: true, onUpdate: true }),
  )
  app.save(products)
  products.listRule = 'ownerId = @request.auth.id || @request.auth.role = "admin" || ownerId = @request.auth.adminId'
  products.viewRule = products.listRule
  products.createRule = '@request.auth.id != ""'
  products.updateRule = 'ownerId = @request.auth.id || @request.auth.role = "admin"'
  products.deleteRule = products.updateRule
  products.indexes = [
    "CREATE INDEX idx_products_owner_name ON products (ownerId, name)",
    "CREATE INDEX idx_products_owner_category ON products (ownerId, category)",
  ]
  app.save(products)

  const orders = new Collection({
    type: "base",
    name: "orders",
  })
  app.save(orders)
  orders.fields.add(
    new JSONField({ name: "items", required: true }),
    new NumberField({ name: "total", required: true, min: 0 }),
    new SelectField({
      name: "status",
      required: true,
      values: ["pending", "ready", "completed"],
      maxSelect: 1,
    }),
    new SelectField({
      name: "orderType",
      required: true,
      values: ["takeaway", "dine_in"],
      maxSelect: 1,
    }),
    new TextField({ name: "paymentMethod", max: 80 }),
    new NumberField({ name: "tenderedAmount", min: 0 }),
    new NumberField({ name: "change", min: 0 }),
    new NumberField({ name: "orderNumber", required: true, onlyInt: true, min: 1 }),
    new TextField({ name: "ownerId", required: true, max: 255 }),
    new TextField({ name: "createdBy", max: 255 }),
    new TextField({ name: "tableNumber", max: 80 }),
    new TextField({ name: "customerName", max: 255 }),
    new AutodateField({ name: "created", onCreate: true }),
    new AutodateField({ name: "updated", onCreate: true, onUpdate: true }),
  )
  app.save(orders)
  orders.listRule = 'ownerId = @request.auth.id || ownerId = @request.auth.adminId || @request.auth.role = "admin"'
  orders.viewRule = orders.listRule
  orders.createRule = '@request.auth.id != ""'
  orders.updateRule = orders.listRule
  orders.deleteRule = 'ownerId = @request.auth.id || @request.auth.role = "admin"'
  orders.indexes = [
    "CREATE INDEX idx_orders_owner_created ON orders (ownerId, created)",
    "CREATE INDEX idx_orders_owner_status ON orders (ownerId, status)",
  ]
  app.save(orders)

  const counters = new Collection({
    type: "base",
    name: "counters",
  })
  app.save(counters)
  counters.fields.add(
    new TextField({ name: "name", required: true, max: 120 }),
    new NumberField({ name: "value", required: true, onlyInt: true, min: 0 }),
    new TextField({ name: "ownerId", required: true, max: 255 }),
    new AutodateField({ name: "created", onCreate: true }),
    new AutodateField({ name: "updated", onCreate: true, onUpdate: true }),
  )
  app.save(counters)
  counters.listRule = 'ownerId = @request.auth.id || ownerId = @request.auth.adminId || @request.auth.role = "admin"'
  counters.viewRule = counters.listRule
  counters.createRule = '@request.auth.id != ""'
  counters.updateRule = counters.listRule
  counters.deleteRule = 'ownerId = @request.auth.id || @request.auth.role = "admin"'
  counters.indexes = [
    "CREATE UNIQUE INDEX idx_counters_owner_name ON counters (ownerId, name)",
  ]
  app.save(counters)

  const tx = new Collection({
    id: "pbc_1970302304",
    type: "base",
    name: "inventory_transactions",
  })
  app.save(tx)
}, (app) => {
  for (const name of ["counters", "orders", "products", "inventory_transactions"]) {
    try {
      const collection = app.findCollectionByNameOrId(name)
      app.delete(collection)
    } catch (_) {}
  }

  const users = app.findCollectionByNameOrId("users")
  for (const name of ["role", "adminId", "isActive", "photoUrl", "createdBy", "lastLoginAt", "deletedAt"]) {
    users.fields.removeByName(name)
  }
  users.listRule = "id = @request.auth.id"
  users.viewRule = "id = @request.auth.id"
  users.createRule = ""
  users.updateRule = "id = @request.auth.id"
  users.deleteRule = "id = @request.auth.id"
  app.save(users)
})
