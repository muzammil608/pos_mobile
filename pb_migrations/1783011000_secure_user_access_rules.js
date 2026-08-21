/// <reference path="../pb_data/types.d.ts" />
migrate((app) => {
  const users = app.findCollectionByNameOrId("users");

  const managedUserRule =
    '@request.auth.id != "" && (id = @request.auth.id || adminId = @request.auth.id || @request.auth.role = "admin")';

  users.listRule = managedUserRule;
  users.viewRule = managedUserRule;
  users.createRule =
    '@request.auth.id != "" && @request.auth.role = "admin"';
  users.updateRule = managedUserRule;
  users.deleteRule = managedUserRule;

  return app.save(users);
}, (app) => {
  const users = app.findCollectionByNameOrId("users");

  users.listRule =
    'id = @request.auth.id || adminId = @request.auth.id || @request.auth.role = "admin"';
  users.viewRule = users.listRule;
  users.createRule =
    '@request.auth.id = "" || @request.auth.role = "admin"';
  users.updateRule = users.listRule;
  users.deleteRule = '@request.auth.id != ""';

  return app.save(users);
});
