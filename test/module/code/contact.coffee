exports.get = (req, res) ->
  res.json {
    name: "Contact ##{req.params.id}"
    id: req.params.id
  }

exports.post = exports.get