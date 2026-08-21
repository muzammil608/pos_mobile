/// <reference path="../pb_data/types.d.ts" />

migrate((app) => {
  const ledgers = new Collection({
    type: "base",
    name: "pay_later_ledgers",
  })
  app.save(ledgers)

  ledgers.fields.add(
    new TextField({ name: "ownerId", required: true, max: 255 }),
    new JSONField({ name: "people" }),
    new TextField({ name: "clientUpdatedAt", max: 80 }),
    new AutodateField({ name: "created", onCreate: true }),
    new AutodateField({ name: "updated", onCreate: true, onUpdate: true }),
  )
  ledgers.listRule =
    'ownerId = @request.auth.id || ownerId = @request.auth.adminId || @request.auth.role = "admin"'
  ledgers.viewRule = ledgers.listRule
  ledgers.createRule = '@request.auth.id != ""'
  ledgers.updateRule = ledgers.listRule
  ledgers.deleteRule =
    'ownerId = @request.auth.id || @request.auth.role = "admin"'
  ledgers.indexes = [
    "CREATE UNIQUE INDEX idx_pay_later_ledgers_owner ON pay_later_ledgers (ownerId)",
  ]
  app.save(ledgers)
}, (app) => {
  try {
    app.delete(app.findCollectionByNameOrId("pay_later_ledgers"))
  } catch (_) {}
})
