migrate((app) => {
  const slides = new Collection({
    type: "base",
    name: "pos_header_slides",
  })
  app.save(slides)

  slides.fields.add(
    new TextField({ name: "ownerId", required: true, max: 255 }),
    new TextField({ name: "badge", required: true, max: 80 }),
    new TextField({ name: "title", required: true, max: 180 }),
    new TextField({ name: "subtitle", max: 255 }),
    new TextField({ name: "startColor", required: true, max: 16 }),
    new TextField({ name: "middleColor", required: true, max: 16 }),
    new TextField({ name: "endColor", required: true, max: 16 }),
    new NumberField({ name: "sortOrder", required: true, onlyInt: true, min: 0 }),
    new BoolField({ name: "isActive" }),
    new AutodateField({ name: "created", onCreate: true }),
    new AutodateField({ name: "updated", onCreate: true, onUpdate: true }),
  )

  slides.listRule = 'ownerId = @request.auth.id || ownerId = @request.auth.adminId || @request.auth.role = "admin"'
  slides.viewRule = slides.listRule
  slides.createRule = '@request.auth.role = "admin"'
  slides.updateRule = 'ownerId = @request.auth.id || @request.auth.role = "admin"'
  slides.deleteRule = slides.updateRule
  slides.indexes = [
    "CREATE INDEX idx_pos_header_slides_owner_sort ON pos_header_slides (ownerId, sortOrder)",
  ]

  app.save(slides)
}, (app) => {
  const slides = app.findCollectionByNameOrId("pos_header_slides")
  app.delete(slides)
})
