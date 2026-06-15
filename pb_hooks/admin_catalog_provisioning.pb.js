/// <reference path="../pb_data/types.d.ts" />

function findCatalogTemplateOwner() {
  const products = $app.findRecordsByFilter(
    "products",
    'ownerId != ""',
    "created",
    1,
    0,
  );
  return products.length === 0 ? "" : products[0].getString("ownerId");
}

function cloneCatalogForAdmin(adminId) {
  if (!adminId) return;

  const existing = $app.findRecordsByFilter(
    "products",
    `ownerId = "${adminId}"`,
    "created",
    1,
    0,
  );
  if (existing.length > 0) return;

  const templateOwnerId = findCatalogTemplateOwner();
  if (!templateOwnerId || templateOwnerId === adminId) return;

  const templates = $app.findRecordsByFilter(
    "products",
    `ownerId = "${templateOwnerId}"`,
    "created",
    0,
    0,
  );
  const productsCollection = $app.findCollectionByNameOrId("products");

  for (const template of templates) {
    const product = new Record(productsCollection);
    product.set("ownerId", adminId);
    product.set("model_code", template.getString("model_code"));
    product.set("brand", template.getString("brand"));
    product.set("item_name", template.getString("item_name"));
    product.set("quality_tier", template.getString("quality_tier"));
    product.set("wholesale_rate", template.getFloat("wholesale_rate"));
    product.set("retail_rate", template.getFloat("retail_rate"));
    product.set("min_sale_price", template.getFloat("min_sale_price"));
    product.set("allow_bargain", template.getBool("allow_bargain"));
    product.set(
      "max_discount_percent",
      template.getFloat("max_discount_percent"),
    );
    product.set("category", template.getString("category"));
    product.set("backup_image_url", template.getString("backup_image_url"));
    product.set("stockQty", template.getInt("stockQty"));
    product.set("lowStockThreshold", template.getInt("lowStockThreshold"));
    product.set("damagedQty", template.getInt("damagedQty"));
    product.set("barcode", template.getString("barcode"));
    $app.save(product);
  }
}

onRecordAfterCreateSuccess((e) => {
  if (e.record.getString("role") === "admin") {
    cloneCatalogForAdmin(e.record.id);
  }
  e.next();
}, "users");
