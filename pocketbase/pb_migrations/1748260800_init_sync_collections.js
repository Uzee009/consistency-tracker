/// Migration: 1748260800_init_sync_collections.js
/// Creates three owner-scoped base collections for cross-device sync:
/// tasks, task_status, day_meta. Each has server-managed `created`/`updated`
/// autodate fields (used as the pull cursor), owner-scoped API rules, and a
/// unique index on the natural key (scoped by owner).
///
/// NOTE (0.38.x): fields MUST be passed via the `fields` property in the
/// Collection constructor. The previous version used `.schema = [...]`, which
/// 0.38.2 silently ignores, producing empty collections. This `up` is
/// re-runnable: it deletes any pre-existing copies of the three collections
/// before recreating them.

migrate((app) => {
  // Make this migration re-runnable: drop pre-existing (possibly broken) copies.
  for (const n of ["day_meta", "task_status", "tasks"]) {
    try {
      const existing = app.findCollectionByNameOrId(n);
      app.delete(existing);
    } catch (_) {
      // not found — nothing to delete
    }
  }

  const users = app.findCollectionByNameOrId("users");

  const RULES = {
    listRule:   "owner = @request.auth.id",
    viewRule:   "owner = @request.auth.id",
    createRule: "@request.auth.id != \"\" && owner = @request.auth.id",
    updateRule: "owner = @request.auth.id",
    deleteRule: "owner = @request.auth.id",
  };

  // tasks
  const tasks = new Collection(Object.assign({
    type: "base",
    name: "tasks",
    fields: [
      { name: "sid", type: "text", required: true },
      { name: "name", type: "text", required: true },
      { name: "type", type: "text", required: true },
      { name: "duration_days", type: "number" },
      { name: "is_perpetual", type: "bool" },
      { name: "created_at", type: "text", required: true },
      { name: "is_active", type: "bool" },
      { name: "frequency_type", type: "text" },
      { name: "weekly_target", type: "number" },
      { name: "updated_at", type: "number" },
      { name: "deleted", type: "bool" },
      { name: "dirty", type: "bool" },
      { name: "owner", type: "relation", required: true, collectionId: users.id, maxSelect: 1, cascadeDelete: true },
      { name: "created", type: "autodate", onCreate: true, onUpdate: false },
      { name: "updated", type: "autodate", onCreate: true, onUpdate: true },
    ],
    indexes: [
      "CREATE UNIQUE INDEX `idx_tasks_owner_sid` ON `tasks` (`owner`, `sid`)",
    ],
  }, RULES));
  app.save(tasks);

  // task_status
  const taskStatus = new Collection(Object.assign({
    type: "base",
    name: "task_status",
    fields: [
      { name: "date", type: "text", required: true },
      { name: "task_sid", type: "text", required: true },
      { name: "status", type: "text", required: true },
      { name: "updated_at", type: "number" },
      { name: "deleted", type: "bool" },
      { name: "dirty", type: "bool" },
      { name: "owner", type: "relation", required: true, collectionId: users.id, maxSelect: 1, cascadeDelete: true },
      { name: "created", type: "autodate", onCreate: true, onUpdate: false },
      { name: "updated", type: "autodate", onCreate: true, onUpdate: true },
    ],
    indexes: [
      "CREATE UNIQUE INDEX `idx_task_status_owner_date_sid` ON `task_status` (`owner`, `date`, `task_sid`)",
    ],
  }, RULES));
  app.save(taskStatus);

  // day_meta
  const dayMeta = new Collection(Object.assign({
    type: "base",
    name: "day_meta",
    fields: [
      { name: "date", type: "text", required: true },
      { name: "cheat_used", type: "bool" },
      { name: "pomodoro_sessions", type: "number" },
      { name: "pomodoro_goal", type: "number" },
      { name: "updated_at", type: "number" },
      { name: "deleted", type: "bool" },
      { name: "dirty", type: "bool" },
      { name: "owner", type: "relation", required: true, collectionId: users.id, maxSelect: 1, cascadeDelete: true },
      { name: "created", type: "autodate", onCreate: true, onUpdate: false },
      { name: "updated", type: "autodate", onCreate: true, onUpdate: true },
    ],
    indexes: [
      "CREATE UNIQUE INDEX `idx_day_meta_owner_date` ON `day_meta` (`owner`, `date`)",
    ],
  }, RULES));
  app.save(dayMeta);
}, (app) => {
  // Rollback: delete the three collections if present.
  for (const n of ["day_meta", "task_status", "tasks"]) {
    try {
      const c = app.findCollectionByNameOrId(n);
      app.delete(c);
    } catch (_) {}
  }
});
