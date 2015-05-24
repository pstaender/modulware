
exports.index = (req, res) ->
  res.send 'hello world'

exports.home = (req, res) ->
  res.render('index', { title: 'home' })
  #res.send 'welcome home'
