/// <reference path="../pb_data/types.d.ts" />

// Universal hook syntax that works perfectly without the "core" object handler
onRecordCreateRequest((e) => {
    const uploadedImage = e.record.get("image");

    if (!uploadedImage) {
        const brandRaw = e.record.get("brand");
        const categoryRaw = e.record.get("category");

        const brand = brandRaw ? brandRaw.toLowerCase() : "generic";
        const category = categoryRaw ? categoryRaw.toLowerCase() : "smartphone";
        
        let keyword = "smartphone";
        if (category === "panels") {
            keyword = "smartphone-screen";
        } else if (category === "chargers") {
            keyword = "phone-charger";
        } else if (category === "cables") {
            keyword = "usb-cable";
        } else if (category === "covers") {
            keyword = "phone-case";
        }

        const randomId = Math.floor(Math.random() * 500) + 1;
        const dynamicWebUrl = `https://images.unsplash.com/photo-1601784551446-20c9e07cdbdb?w=600&q=80&sig=${randomId}&q=${keyword}`;
        
        e.record.set("backup_image_url", dynamicWebUrl);
    }

    return e.next();
}, "products");