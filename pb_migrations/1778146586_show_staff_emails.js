/// <reference path="../pb_data/types.d.ts" />
migrate((app) => {
  const records = app.findRecordsByFilter(
    "users",
    'emailVisibility = false && (role = "cashier" || role = "kitchen")',
    "",
    0,
    0,
  )

  for (const record of records) {
    record.set("emailVisibility", true)
    app.save(record)
  }
}, (app) => {
  const records = app.findRecordsByFilter(
    "users",
    'emailVisibility = true && (role = "cashier" || role = "kitchen")',
    "",
    0,
    0,
  )

  for (const record of records) {
    record.set("emailVisibility", false)
    app.save(record)
  }
})
