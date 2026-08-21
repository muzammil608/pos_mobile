/// <reference path="../pb_data/types.d.ts" />

migrate((app) => {
  const products = app.findCollectionByNameOrId("products")
  const savedBrands = {}

  for (const record of app.findRecordsByFilter(
    "products",
    "",
    "created",
    0,
    0,
  )) {
    savedBrands[record.id] = record.getString("brand")
  }

  try {
    products.fields.removeByName("brand")
  } catch (_) {}

  products.fields.add(
    new TextField({
      name: "brand",
      required: true,
      min: 1,
      max: 120,
    }),
  )
  app.save(products)

  for (const record of app.findRecordsByFilter(
    "products",
    "",
    "created",
    0,
    0,
  )) {
    record.set("brand", savedBrands[record.id] || "Other")
    app.saveNoValidate(record)
  }
}, (app) => {
  // Keep brand as free text on rollback so custom product brands aren't lost.
})
