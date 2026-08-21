/// <reference path="../pb_data/types.d.ts" />

migrate((app) => {
  // 1. Drop trigger first to prevent SQLite from blocking column drops
  try {
    app.db().newQuery(`
      DROP TRIGGER IF EXISTS trg_orders_after_insert_inventory_sale
    `).execute();
  } catch (_) {}

  const products = app.findCollectionByNameOrId("products");

  // 2. Remove old fields
  for (const name of ["name", "price", "imageUrl", "iconCodePoint", "purchasePrice", "category"]) {
    try {
      products.fields.removeByName(name);
    } catch (_) {}
  }

  // 3. Add new fields
  products.fields.add(
    new TextField({
      name: "model_code",
      required: true,
      min: 1,
      max: 50,
    }),
    new SelectField({
      name: "brand",
      required: true,
      maxSelect: 1,
      values: ["Infinix", "Tecno", "Samsung", "Oppo", "Vivo", "Xiaomi", "Realme", "Apple"],
    }),
    new TextField({
      name: "item_name",
      required: true,
      min: 3,
      max: 200,
    }),
    new SelectField({
      name: "quality_tier",
      required: true,
      maxSelect: 1,
      values: ["Normal Copy", "Icon Quality", "Mabroor", "Original Pull"],
    }),
    new NumberField({
      name: "wholesale_rate",
      required: true,
      min: 0,
    }),
    new NumberField({
      name: "retail_rate",
      required: true,
      min: 0,
    }),
    new SelectField({
      name: "category",
      required: true,
      maxSelect: 1,
      values: ["panels", "chargers", "cables", "covers"],
    }),
    new TextField({
      name: "backup_image_url",
      required: false,
      max: 500,
    })
  );

  // 4. Update collection indexes to use new field names
  products.indexes = [
    "CREATE INDEX idx_products_owner_item_name ON products (ownerId, item_name)",
    "CREATE INDEX idx_products_owner_category ON products (ownerId, category)",
  ];

  // Save the collection changes (drops old fields, adds new ones, updates indexes)
  app.save(products);

  // 5. Recreate SQLite Trigger for inventory sale, replacing p.name with p.item_name
  app.db().newQuery(`
    CREATE TRIGGER trg_orders_after_insert_inventory_sale
    AFTER INSERT ON orders
    BEGIN
      INSERT INTO inventory_transactions (
        id,
        ownerId,
        productId,
        productName,
        type,
        quantity,
        previousStock,
        newStock,
        orderId,
        note,
        created,
        updated
      )
      SELECT
        substr(lower(hex(randomblob(8))), 1, 15),
        COALESCE(NULLIF(p.ownerId, ''), NEW.ownerId),
        p.id,
        COALESCE(NULLIF(json_extract(item.value, '$.name'), ''), p.item_name),
        'sale',
        CAST(COALESCE(json_extract(item.value, '$.qty'), json_extract(item.value, '$.quantity'), 0) AS INTEGER),
        p.stockQty,
        p.stockQty - CAST(COALESCE(json_extract(item.value, '$.qty'), json_extract(item.value, '$.quantity'), 0) AS INTEGER),
        NEW.id,
        '',
        strftime('%Y-%m-%d %H:%M:%fZ', 'now'),
        strftime('%Y-%m-%d %H:%M:%fZ', 'now')
      FROM json_each(NEW.items) AS item
      JOIN products AS p
        ON p.id = json_extract(item.value, '$.productId')
      WHERE CAST(COALESCE(json_extract(item.value, '$.qty'), json_extract(item.value, '$.quantity'), 0) AS INTEGER) > 0
        AND CAST(COALESCE(json_extract(item.value, '$.qty'), json_extract(item.value, '$.quantity'), 0) AS INTEGER) <= p.stockQty;

      UPDATE products
      SET stockQty = stockQty - (
        SELECT COALESCE(SUM(CAST(COALESCE(json_extract(item.value, '$.qty'), json_extract(item.value, '$.quantity'), 0) AS INTEGER)), 0)
        FROM json_each(NEW.items) AS item
        WHERE json_extract(item.value, '$.productId') = products.id
      )
      WHERE EXISTS (
        SELECT 1
        FROM json_each(NEW.items) AS item
        WHERE json_extract(item.value, '$.productId') = products.id
          AND CAST(COALESCE(json_extract(item.value, '$.qty'), json_extract(item.value, '$.quantity'), 0) AS INTEGER) > 0
      )
        AND stockQty >= (
          SELECT COALESCE(SUM(CAST(COALESCE(json_extract(item.value, '$.qty'), json_extract(item.value, '$.quantity'), 0) AS INTEGER)), 0)
          FROM json_each(NEW.items) AS item
          WHERE json_extract(item.value, '$.productId') = products.id
        );
    END
  `).execute();
}, (app) => {
  // One-way migration
});
