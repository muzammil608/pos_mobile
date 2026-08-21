/// <reference path="../pb_data/types.d.ts" />
migrate((app) => {
  // 1. Disable OAuth2 on users collection (removes warnings about registered providers)
  const users = app.findCollectionByNameOrId("users");
  unmarshal({
    "oauth2": {
      "enabled": false
    }
  }, users);

  // 2. Remove "kitchen" role from user role options
  try {
    const roleField = users.fields.getByName("role");
    if (roleField) {
      roleField.values = ["admin", "cashier"];
    }
  } catch (_) {}
  app.save(users);

  // 3. Remove restaurant dine-in / table fields from orders collection
  try {
    const orders = app.findCollectionByNameOrId("orders");
    orders.fields.removeByName("orderType");
    orders.fields.removeByName("tableNumber");
    app.save(orders);
  } catch (_) {}

}, (app) => {
  // Down migration (roll back to original)
  const users = app.findCollectionByNameOrId("users");
  unmarshal({
    "oauth2": {
      "enabled": true
    }
  }, users);

  try {
    const roleField = users.fields.getByName("role");
    if (roleField) {
      roleField.values = ["admin", "cashier", "kitchen"];
    }
  } catch (_) {}
  app.save(users);

  try {
    const orders = app.findCollectionByNameOrId("orders");
    orders.fields.add(
      new SelectField({
        name: "orderType",
        required: true,
        values: ["takeaway", "dine_in"],
        maxSelect: 1,
      }),
      new TextField({ name: "tableNumber", max: 80 })
    );
    app.save(orders);
  } catch (_) {}
});
