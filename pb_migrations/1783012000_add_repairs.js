/// <reference path="../pb_data/types.d.ts" />

migrate((app) => {
  const repairs = new Collection({
    type: "base",
    name: "repairs",
  })
  app.save(repairs)

  repairs.fields.add(
    new NumberField({
      name: "jobNumber",
      required: true,
      onlyInt: true,
      min: 1,
    }),
    new TextField({ name: "customerName", required: true, max: 255 }),
    new TextField({ name: "customerPhone", required: true, max: 80 }),
    new TextField({ name: "deviceBrand", required: true, max: 120 }),
    new TextField({ name: "deviceModel", required: true, max: 180 }),
    new TextField({ name: "serialNumber", max: 255 }),
    new TextField({ name: "problemDescription", required: true, max: 5000 }),
    new TextField({ name: "technicianNotes", max: 5000 }),
    new TextField({ name: "assignedTechnician", max: 255 }),
    new SelectField({
      name: "status",
      required: true,
      values: [
        "received",
        "diagnosing",
        "awaiting_approval",
        "waiting_for_parts",
        "in_progress",
        "ready_for_pickup",
        "completed",
        "cancelled",
      ],
      maxSelect: 1,
    }),
    new NumberField({ name: "estimatedCost", min: 0 }),
    new NumberField({ name: "advancePayment", min: 0 }),
    new JSONField({ name: "partsUsed" }),
    new DateField({ name: "expectedDeliveryDate" }),
    new DateField({ name: "completedDate" }),
    new TextField({ name: "ownerId", required: true, max: 255 }),
    new TextField({ name: "createdBy", required: true, max: 255 }),
    new AutodateField({ name: "created", onCreate: true }),
    new AutodateField({ name: "updated", onCreate: true, onUpdate: true }),
  )

  repairs.listRule =
    'ownerId = @request.auth.id || ownerId = @request.auth.adminId || @request.auth.role = "admin"'
  repairs.viewRule = repairs.listRule
  repairs.createRule = '@request.auth.id != ""'
  repairs.updateRule = repairs.listRule
  repairs.deleteRule =
    'ownerId = @request.auth.id || @request.auth.role = "admin"'
  repairs.indexes = [
    "CREATE UNIQUE INDEX idx_repairs_owner_job ON repairs (ownerId, jobNumber)",
    "CREATE INDEX idx_repairs_owner_status ON repairs (ownerId, status)",
    "CREATE INDEX idx_repairs_owner_created ON repairs (ownerId, created)",
    "CREATE INDEX idx_repairs_customer_phone ON repairs (customerPhone)",
  ]
  app.save(repairs)
}, (app) => {
  try {
    app.delete(app.findCollectionByNameOrId("repairs"))
  } catch (_) {}
})
