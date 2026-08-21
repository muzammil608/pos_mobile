/// <reference path="../pb_data/types.d.ts" />
migrate((app) => {
  // 1. Delete the pos_header_slides collection
  try {
    const slides = app.findCollectionByNameOrId("pos_header_slides");
    if (slides) {
      app.delete(slides);
    }
  } catch (_) {}

  // 2. Remove the posHeaderSlides field from the users collection
  try {
    const users = app.findCollectionByNameOrId("users");
    if (users) {
      users.fields.removeByName("posHeaderSlides");
      app.save(users);
    }
  } catch (_) {}
}, (app) => {
  // Rollback logic is omitted for simplicity or we can add it if needed
})
