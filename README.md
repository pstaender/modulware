# Modulware - Middleware for modules
## … helps you to organize modular stuff via subfolders in your webapplication

[![Build Status](https://api.travis-ci.org/pstaender/modulware.png)](https://travis-ci.org/pstaender/modulware)

Wording attention: Here module(s) **are not** the libraries you usually find in `node_modules`! In our case modules are folders including code, config, routes and translation data for your webapplication. They should keep your project more modular and organized… you could also regard them as plugins.

## Example

A submodule (`mysubmodule`) could look like:

```
+ project/
┃
┠─ server.js
┠─ package.json
┃

…

┖─ + mysubmodule/
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

[Take a deeper look here](https://github.com/pstaender/modulware/tree/master/examples/mymodule)…

You can use `js` or `coffeescript` files, depending on your compiler; they are included by the js `required` method.

Since it's a middleware, you have to combine it with frameworks. For now it work exclusively with `expressjs`:

```coffeescript
express = require('express')
app = express()
app.set('view engine', 'jade')

Modulware = require('modulware')
mw = new Modulware(app)
server = app.listen 3000, ->
  console.log('server is running')
```

## Development status

Early alpha, not ready for production. Tested against the latest `expressjs` framework. Not on npm, yet.

## Tests

```sh
  $ npm install .
  $ mocha
```

## License

MIT

