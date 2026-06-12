/// <reference path="../pb_data/types.d.ts" />

migrate((app) => {
  const products = app.findCollectionByNameOrId("products");

  // 1. Update brand SelectField values to include new brands
  const brandField = products.fields.getByName("brand");
  if (brandField) {
    brandField.values = [
      "Infinix", "Tecno", "Samsung", "Oppo", "Vivo", "Xiaomi", "Realme", "Apple",
      "Daw-Link", "Generic", "Ronin", "Audionic", "Anker", "Baseus", "Remax",
      "Dany", "Joyroom", "Faster", "LDNIO", "Oraimo", "Yesido", "Other"
    ];
  }

  // 2. Update category SelectField values to include new categories
  const categoryField = products.fields.getByName("category");
  if (categoryField) {
    categoryField.values = [
      "panels", "chargers", "cables", "covers",
      "Audio", "Power", "Protection", "Mounts & Gear"
    ];
  }

  app.save(products);

  // 3. Find default owner (first admin)
  let ownerId = "n5ymkuq74ymi20t"; // fallback
  try {
    const admin = app.findFirstRecordByFilter("users", "role = 'admin'");
    if (admin) {
      ownerId = admin.id;
    }
  } catch (_) {}

  const productsCollection = app.findCollectionByNameOrId("products");

  const itemsToSeed = [
    {"id": "AUD-001", "name": "Daw-Link Lollapalooza Pro TWS", "brand": "Daw-Link", "category": "Audio", "cost_price": 3800, "retail_price": 5000, "stock": 45, "compatibility": "Universal"},
    {"id": "AUD-002", "name": "AirPod Pro 2 Clone (Master Copy)", "brand": "Generic", "category": "Audio", "cost_price": 1800, "retail_price": 3200, "stock": 120, "compatibility": "iOS, Android"},
    {"id": "AUD-003", "name": "Ronin R-520 Wireless Earbuds", "brand": "Ronin", "category": "Audio", "cost_price": 2400, "retail_price": 3500, "stock": 60, "compatibility": "Universal"},
    {"id": "AUD-004", "name": "Audionic Airbud 400", "brand": "Audionic", "category": "Audio", "cost_price": 2900, "retail_price": 4200, "stock": 35, "compatibility": "Universal"},
    {"id": "AUD-005", "name": "Anker Soundcore Life P2i", "brand": "Anker", "category": "Audio", "cost_price": 5200, "retail_price": 6800, "stock": 20, "compatibility": "Universal"},
    {"id": "AUD-006", "name": "Xiaomi Redmi Buds 5", "brand": "Xiaomi", "category": "Audio", "cost_price": 4100, "retail_price": 5500, "stock": 30, "compatibility": "Universal"},
    {"id": "AUD-007", "name": "Baseus Bowie WM02 TWS", "brand": "Baseus", "category": "Audio", "cost_price": 2800, "retail_price": 3900, "stock": 55, "compatibility": "Universal"},
    {"id": "AUD-008", "name": "Realme Buds T300 ANC", "brand": "Realme", "category": "Audio", "cost_price": 5100, "retail_price": 6999, "stock": 25, "compatibility": "Universal"},
    {"id": "AUD-009", "name": "Ronin R-9 Metallic Earphones", "brand": "Ronin", "category": "Audio", "cost_price": 450, "retail_price": 850, "stock": 200, "compatibility": "3.5mm Jack"},
    {"id": "AUD-010", "name": "Samsung Type-C AKG Earphones", "brand": "Samsung", "category": "Audio", "cost_price": 950, "retail_price": 1800, "stock": 150, "compatibility": "Type-C Devices"},

    {"id": "PWR-011", "name": "Daw-Link 20000mAh Power Bank", "brand": "Daw-Link", "category": "Power", "cost_price": 3900, "retail_price": 4999, "stock": 40, "compatibility": "Universal"},
    {"id": "PWR-012", "name": "Remax RPP-623 10000mAh 22.5W", "brand": "Remax", "category": "Power", "cost_price": 2600, "retail_price": 3500, "stock": 70, "compatibility": "Universal"},
    {"id": "PWR-013", "name": "Anker PowerCore 20K II 30W", "brand": "Anker", "category": "Power", "cost_price": 8500, "retail_price": 11500, "stock": 15, "compatibility": "Universal"},
    {"id": "PWR-014", "name": "Xiaomi Pocket Edition 10000mAh", "brand": "Xiaomi", "category": "Power", "cost_price": 3400, "retail_price": 4500, "stock": 50, "compatibility": "Universal"},
    {"id": "PWR-015", "name": "Baseus Adaman 65W 20000mAh", "brand": "Baseus", "category": "Power", "cost_price": 7200, "retail_price": 9800, "stock": 18, "compatibility": "Laptops, Mobiles"},
    {"id": "PWR-016", "name": "Ronin R-83 10000mAh Compact", "brand": "Ronin", "category": "Power", "cost_price": 1900, "retail_price": 2800, "stock": 85, "compatibility": "Universal"},
    {"id": "PWR-017", "name": "Dany Power Bank G-15 15K", "brand": "Dany", "category": "Power", "cost_price": 2800, "retail_price": 3999, "stock": 40, "compatibility": "Universal"},
    {"id": "PWR-018", "name": "Infinix 15W Wireless Power Bank", "brand": "Infinix", "category": "Power", "cost_price": 3100, "retail_price": 4500, "stock": 30, "compatibility": "Qi Wireless Devices"},
    {"id": "PWR-019", "name": "Joyroom 22.5W Mini Power Bank", "brand": "Joyroom", "category": "Power", "cost_price": 2300, "retail_price": 3400, "stock": 65, "compatibility": "Universal"},
    {"id": "PWR-020", "name": "Faster 10000mAh Slim Power Bank", "brand": "Faster", "category": "Power", "cost_price": 1650, "retail_price": 2500, "stock": 110, "compatibility": "Universal"},

    {"id": "CHG-021", "name": "Daw-Link 45W GaN Charger", "brand": "Daw-Link", "category": "Chargers", "cost_price": 1050, "retail_price": 1500, "stock": 90, "compatibility": "Type-C PD"},
    {"id": "CHG-022", "name": "Apple 20W PD Adapter Clone", "brand": "Generic", "category": "Chargers", "cost_price": 650, "retail_price": 1350, "stock": 250, "compatibility": "iPhone 12-16"},
    {"id": "CHG-023", "name": "Anker 313 Charger 45W Ace", "brand": "Anker", "category": "Chargers", "cost_price": 3100, "retail_price": 4500, "stock": 25, "compatibility": "Samsung Super Fast 2.0"},
    {"id": "CHG-024", "name": "Samsung 25W PD Travel Adapter", "brand": "Samsung", "category": "Chargers", "cost_price": 1400, "retail_price": 2400, "stock": 130, "compatibility": "Samsung S-Series/A-Series"},
    {"id": "CHG-025", "name": "Infinix 68W Super Charge Adapter", "brand": "Infinix", "category": "Chargers", "cost_price": 1800, "retail_price": 2800, "stock": 75, "compatibility": "Infinix, Tecno"},
    {"id": "CHG-026", "name": "Xiaomi 67W Turbo Charger Combo", "brand": "Xiaomi", "category": "Chargers", "cost_price": 2200, "retail_price": 3500, "stock": 60, "compatibility": "Xiaomi SonicCharge"},
    {"id": "CHG-027", "name": "Baseus 30W Super Si Adapter", "brand": "Baseus", "category": "Chargers", "cost_price": 1600, "retail_price": 2499, "stock": 80, "compatibility": "Universal PD"},
    {"id": "CHG-028", "name": "Ronin R-710 Smart Charger 2.4A", "brand": "Ronin", "category": "Chargers", "cost_price": 550, "retail_price": 999, "stock": 180, "compatibility": "Dual USB Android"},
    {"id": "CHG-029", "name": "LDNIO A2316C 20W Dual Port", "brand": "LDNIO", "category": "Chargers", "cost_price": 900, "retail_price": 1500, "stock": 140, "compatibility": "PD + QC 3.0"},
    {"id": "CHG-030", "name": "Oraimo Firefly 3 Smart Charger", "brand": "Oraimo", "category": "Chargers", "cost_price": 480, "retail_price": 850, "stock": 210, "compatibility": "Micro USB"},

    {"id": "CBL-031", "name": "120W Type-C to Type-C Cable", "brand": "Daw-Link", "category": "Cables", "cost_price": 450, "retail_price": 950, "stock": 300, "compatibility": "Type-C Laptops/Phones"},
    {"id": "CBL-032", "name": "Anker PowerLine+ II Lightning 3ft", "brand": "Anker", "category": "Cables", "cost_price": 1900, "retail_price": 2800, "stock": 40, "compatibility": "iPhone Lightning"},
    {"id": "CBL-033", "name": "Baseus Cafule Type-C 3A Cable", "brand": "Baseus", "category": "Cables", "cost_price": 550, "retail_price": 999, "stock": 160, "compatibility": "Android Fast Charge"},
    {"id": "CBL-034", "name": "Ronin R-50 Heavy Duty iOS Cable", "brand": "Ronin", "category": "Cables", "cost_price": 320, "retail_price": 650, "stock": 220, "compatibility": "iPhone"},
    {"id": "CBL-035", "name": "Remax RC-190 60W Travel Box Case", "brand": "Remax", "category": "Cables", "cost_price": 950, "retail_price": 1600, "stock": 50, "compatibility": "Multi-connector Kit"},
    {"id": "CBL-036", "name": "Generic 3-in-1 Charging Cable", "brand": "Generic", "category": "Cables", "cost_price": 180, "retail_price": 450, "stock": 400, "compatibility": "Micro, Type-C, Lightning"},
    {"id": "CBL-037", "name": "Joyroom 100W Fast Charging Cable", "brand": "Joyroom", "category": "Cables", "cost_price": 680, "retail_price": 1250, "stock": 95, "compatibility": "PD Laptops/Mobiles"},
    {"id": "CBL-038", "name": "Faster Nylon Braided Type-C Cable", "brand": "Faster", "category": "Cables", "cost_price": 210, "retail_price": 499, "stock": 280, "compatibility": "Type-C Devices"},
    {"id": "CBL-039", "name": "LDNIO LC1302 Twin Lightning Cable", "brand": "LDNIO", "category": "Cables", "cost_price": 400, "retail_price": 750, "stock": 110, "compatibility": "iOS Devices"},
    {"id": "CBL-040", "name": "Samsung Original Type-C to C 1m", "brand": "Samsung", "category": "Cables", "cost_price": 600, "retail_price": 1200, "stock": 190, "compatibility": "Samsung Flagships"},

    {"id": "PRT-041", "name": "iPhone 15/16 Pro Max Silicon Case", "brand": "Generic", "category": "Protection", "cost_price": 350, "retail_price": 950, "stock": 500, "compatibility": "iPhone 15/16 Pro Max"},
    {"id": "PRT-042", "name": "Samsung S24 Ultra MagSafe Clear Case", "brand": "Generic", "category": "Protection", "cost_price": 450, "retail_price": 1200, "stock": 150, "compatibility": "Samsung S24 Ultra"},
    {"id": "PRT-043", "name": "9D Curved Tempered Glass Screen Guard", "brand": "Generic", "category": "Protection", "cost_price": 80, "retail_price": 350, "stock": 1000, "compatibility": "All Android/iOS models"},
    {"id": "PRT-044", "name": "Spigen Liquid Air Case Replica", "brand": "Generic", "category": "Protection", "cost_price": 500, "retail_price": 1500, "stock": 80, "compatibility": "Premium Androids"},
    {"id": "PRT-045", "name": "Camera Lens Protector Rings Set", "brand": "Generic", "category": "Protection", "cost_price": 180, "retail_price": 600, "stock": 350, "compatibility": "iPhone 14/15/16 Pro"},

    {"id": "MSC-046", "name": "Wireless Bluetooth Tripod Stand", "brand": "Generic", "category": "Mounts & Gear", "cost_price": 400, "retail_price": 850, "stock": 140, "compatibility": "Universal Mobiles"},
    {"id": "MSC-047", "name": "360 Rearview Mirror Car Holder", "brand": "Generic", "category": "Mounts & Gear", "cost_price": 190, "retail_price": 499, "stock": 170, "compatibility": "Universal Cars"},
    {"id": "MSC-048", "name": "Magnetic Dashboard Car Mount", "brand": "Yesido", "category": "Mounts & Gear", "cost_price": 450, "retail_price": 999, "stock": 120, "compatibility": "Universal MagSafe/Plates"},
    {"id": "MSC-049", "name": "PUBG Mobile 4-Finger Gaming Triggers", "brand": "Generic", "category": "Mounts & Gear", "cost_price": 120, "retail_price": 350, "stock": 400, "compatibility": "All Smartphones"},
    {"id": "MSC-050", "name": "Magsafe Wireless Card Wallet", "brand": "Generic", "category": "Mounts & Gear", "cost_price": 300, "retail_price": 850, "stock": 200, "compatibility": "iPhone 12-16 / MagSafe cases"}
  ];

  for (const item of itemsToSeed) {
    // Map Chargers and Cables categories to lowercase to align with existing db values
    let category = item.category;
    if (category === "Chargers") {
      category = "chargers";
    } else if (category === "Cables") {
      category = "cables";
    }

    // Check if the product already exists (to avoid duplicate seeds on migration reruns)
    try {
      const existing = app.findFirstRecordByFilter("products", `model_code = "${item.id}" && ownerId = "${ownerId}"`);
      if (existing) continue;
    } catch (_) {}

    const record = new Record(productsCollection);
    record.set("ownerId", ownerId);
    record.set("model_code", item.id);
    record.set("brand", item.brand);
    record.set("item_name", item.name);
    record.set("quality_tier", "Normal Copy");
    record.set("wholesale_rate", item.cost_price);
    record.set("retail_rate", item.retail_price);
    record.set("category", category);
    record.set("stockQty", item.stock);
    record.set("lowStockThreshold", 5);
    record.set("damagedQty", 0);
    record.set("barcode", item.compatibility || "");

    app.save(record);
  }
}, (app) => {
  // One-way seed migration
});
