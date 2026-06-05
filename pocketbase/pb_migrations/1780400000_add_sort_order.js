/// Migration: 1780400000_add_sort_order.js
/// Adds optional `sort_order` (number) field to tasks collection
/// for cross-device manual reordering.

migrate((app) => {
  const name = 'tasks';
  const c = app.findCollectionByNameOrId(name);
  const field = new Field({
    name: 'sort_order',
    type: 'number',
    required: false,
  });
  c.fields.add(field);
  app.save(c);
}, (app) => {
  // Rollback
  const name = 'tasks';
  try {
    const c = app.findCollectionByNameOrId(name);
    const field = c.fields.findByName('sort_order');
    if (field) {
      c.fields.removeById(field.id);
      app.save(c);
    }
  } catch (_) {}
});
