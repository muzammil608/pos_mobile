/// <reference path="../pb_data/types.d.ts" />

migrate((app) => {
  const products = app.findCollectionByNameOrId("products")

  const addField = (field) => {
    if (!products.fields.getByName(field.name)) {
      products.fields.add(field)
    }
  }

  addField(
    new NumberField({
      name: "min_sale_price",
      required: false,
      min: 0,
    }),
  )
  addField(
    new BoolField({
      name: "allow_bargain",
      required: false,
    }),
  )
  addField(
    new NumberField({
      name: "max_discount_percent",
      required: false,
      min: 0,
      max: 100,
    }),
  )

  app.save(products)
}, (app) => {
  const products = app.findCollectionByNameOrId("products")
  for (const name of [
    "min_sale_price",
    "allow_bargain",
    "max_discount_percent",
  ]) {
    try {
      products.fields.removeByName(name)
    } catch (_) {}
  }
  app.save(products)
})
