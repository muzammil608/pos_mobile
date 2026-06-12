/// <reference path="../pb_data/types.d.ts" />

migrate((app) => {
  app.db().newQuery(`
    DROP TRIGGER IF EXISTS trg_orders_after_insert_inventory_sale
  `).execute()

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
        COALESCE(NULLIF(json_extract(item.value, '$.name'), ''), p.name),
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
  `).execute()
}, (app) => {
  app.db().newQuery(`
    DROP TRIGGER IF EXISTS trg_orders_after_insert_inventory_sale
  `).execute()
})
