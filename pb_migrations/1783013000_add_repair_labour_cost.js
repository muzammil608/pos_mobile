/// <reference path="../pb_data/types.d.ts" />

migrate((app) => {
  const repairs = app.findCollectionByNameOrId("repairs")
  if (!repairs.fields.getByName("labourCost")) {
    repairs.fields.add(
      new NumberField({ name: "labourCost", min: 0 }),
    )
    app.save(repairs)
  }
}, (app) => {
  const repairs = app.findCollectionByNameOrId("repairs")
  repairs.fields.removeByName("labourCost")
  app.save(repairs)
})
