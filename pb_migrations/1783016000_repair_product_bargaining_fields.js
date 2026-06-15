/// <reference path="../pb_data/types.d.ts" />

migrate((app) => {
  const products = app.findCollectionByNameOrId("products")

  const hasField = (name) => {
    try {
      return products.fields.getByName(name) != null
    } catch (_) {
      return false
    }
  }

  if (!hasField("min_sale_price")) {
    products.fields.add(
      new NumberField({
        name: "min_sale_price",
        required: false,
        min: 0,
      }),
    )
  }
  if (!hasField("allow_bargain")) {
    products.fields.add(
      new BoolField({
        name: "allow_bargain",
        required: false,
      }),
    )
  }
  if (!hasField("max_discount_percent")) {
    products.fields.add(
      new NumberField({
        name: "max_discount_percent",
        required: false,
        min: 0,
        max: 100,
      }),
    )
  }

  app.save(products)
}, (app) => {
  // Keep the repaired fields on rollback to avoid discarding product policy.
})
