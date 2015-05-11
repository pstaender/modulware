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

You can use `js` or `coffeescript` files, depending on your compiler; they are included by the js `required` method.

Since it's a middleware, you have to combine it with frameworks. For now it work exclusively with `expressjs`:

```coffeescript
express = require('express')
app = express()

modulware = require('modulware')()
# or with options if you want to override the default settings (see: https://github.com/pstaender/modulware/blob/master/modulware.coffee#L7)
# options = { defaultHTTPMethod: 'GET'}
modulware.applyMethods(app)
app.locals.config = modulware.getConfig()

server = app.listen 3000, ->
  console.log('server is running')
```

## Development status

Early alpha, not ready for production. Tested against the latest `expressjs` framework. Not on npm, yet.

## Tests

Maybe later…

## License

MIT

