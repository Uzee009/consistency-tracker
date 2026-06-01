/// Migration: 1780300000_add_device_id.js
/// Adds optional `device_id` (text) field to tasks, task_status, day_meta
/// for client-side realtime self-echo suppression.

migrate((app) => {
  for (const name of ['tasks', 'task_status', 'day_meta']) {
    const c = app.findCollectionByNameOrId(name);
    const field = new Field({
      name: 'device_id',
      type: 'text',
      required: false,
    });
    c.fields.add(field);
    app.save(c);
  }
}, (app) => {
  // Rollback
  for (const name of ['tasks', 'task_status', 'day_meta']) {
    try {
      const c = app.findCollectionByNameOrId(name);
      const field = c.fields.findByName('device_id');
      if (field) {
        c.fields.removeById(field.id);
        app.save(c);
      }
    } catch (_) {}
  }
});
