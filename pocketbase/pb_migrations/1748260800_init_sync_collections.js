/// Migration: 1748260800_init_sync_collections.js
/// Creates three base collections for cross-device sync.

migrate((db) => {
  const usersId = db.findCollectionByNameOrId("users").id;

  // Create tasks collection (rules can be set in admin UI later)
  const tasks = new Collection({
    id: "tasks",
    name: "tasks",
    type: "base",
    system: false,
  });

  tasks.schema = [
    {name: "sid", type: "text", required: true, presentable: false},
    {name: "name", type: "text", required: true, presentable: false},
    {name: "type", type: "text", required: true, presentable: false},
    {name: "duration_days", type: "number", required: true, presentable: false},
    {name: "is_perpetual", type: "bool", presentable: false},
    {name: "created_at", type: "text", required: true, presentable: false},
    {name: "is_active", type: "bool", presentable: false},
    {name: "frequency_type", type: "text", presentable: false},
    {name: "weekly_target", type: "number", presentable: false},
    {name: "updated_at", type: "number", required: true, presentable: false},
    {name: "deleted", type: "bool", presentable: false},
    {name: "dirty", type: "bool", presentable: false},
    {name: "owner", type: "relation", required: true, presentable: false, collectionId: usersId, maxSelect: 1, cascadeDelete: true},
  ];

  db.save(tasks);

  // Create task_status collection
  const taskStatus = new Collection({
    id: "task_status",
    name: "task_status",
    type: "base",
    system: false,
  });

  taskStatus.schema = [
    {name: "date", type: "text", required: true, presentable: false},
    {name: "task_sid", type: "text", required: true, presentable: false},
    {name: "status", type: "text", required: true, presentable: false},
    {name: "updated_at", type: "number", required: true, presentable: false},
    {name: "deleted", type: "bool", presentable: false},
    {name: "dirty", type: "bool", presentable: false},
    {name: "owner", type: "relation", required: true, presentable: false, collectionId: usersId, maxSelect: 1, cascadeDelete: true},
  ];

  db.save(taskStatus);

  // Create day_meta collection
  const dayMeta = new Collection({
    id: "day_meta",
    name: "day_meta",
    type: "base",
    system: false,
  });

  dayMeta.schema = [
    {name: "date", type: "text", required: true, presentable: false},
    {name: "cheat_used", type: "bool", presentable: false},
    {name: "pomodoro_sessions", type: "number", presentable: false},
    {name: "pomodoro_goal", type: "number", presentable: false},
    {name: "updated_at", type: "number", required: true, presentable: false},
    {name: "deleted", type: "bool", presentable: false},
    {name: "dirty", type: "bool", presentable: false},
    {name: "owner", type: "relation", required: true, presentable: false, collectionId: usersId, maxSelect: 1, cascadeDelete: true},
  ];

  db.save(dayMeta);
}, (db) => {
  // Rollback: Leave collections intact for safety
});
