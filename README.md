# Modulware
## … helps you to organize plugins via folders in your webapplication

Here module(s) **are not** `node_modules` :) Modules are folders including code, config and routes for your webapplication, to keep it modular and a bit more organized.

## Example

A submodule could be:

```
+ project/
┃
┠─ server.js
┠─ package.json
┃
┖─ + mysubmodulemodule/
   ┃
   ┠─ routes.yml
   ┠─ config.yml
   ┃
   ┖─ + code/
      ┃
      ┠─ frontpage.js
      ┖─ + models/
         ┖─ contact.js
```

Example for `routes.yml`:

```yaml
routes:
  '/': frontpage.index
  'GET:/contact/:id([0-9]+)': contact.get
  'POST:/contact/:id([0-9]+)': contact.post
```

## Development status

Early alpha, not ready for production. Tested against the latest `expressjs` framework.

## Tests

Maybe later…

## License

MIT

