yaml = require 'js-yaml'
glob = require 'glob'
fs   = require 'fs'
path = require 'path'
_    = require 'underscore'

defaultConfig = {
  configFilePattern: 'config.@(yml|yaml)'
  routesFile: 'routes.yml'
  codeFilePattern: 'code/**/*.@(coffee|js)'
  i18nFilePattern: 'i18n/**/*.@(yml|yaml)'
  defaultHTTPMethod: '*' # can be get|put|post|delete|patch|all|*(is for all)
  debug: true
  encoding: 'utf8'
  moduleNamePattern: '^[a-zA-Z\\_\\-0-9]+$'
  basedir: null
}

_options = {}
_config = {}
_modules = {}
_i18n = {}
_sortedRoutes = []

module.exports = (options = {}, app = null) ->
  exports.setOptions(options)
  exports.buildIndexByModules() if typeof app is 'function'
  exports

exports.setOptions = (options) ->
  # apply options over default options
  _.extendOwn(_options, defaultConfig, options)
  unless _options.basedir
    _options.basedir = path.dirname(process.argv[1])
  _options

exports.applyMethods = (app) ->
  return @log.error('app argument needs to be a function') if typeof app isnt 'function'
  exports.buildModuleIndex()
  exports.applyOnApp(app)

exports.log = {
  error:      ->
    args = Array.prototype.slice.call(arguments)
    args.unshift('[error]')
    console.error.apply(console, args)
  fatalError: (msg) ->
    args = Array.prototype.slice.call(arguments)
    args.unshift('[fatalError]')
    console.error.apply(console, args)
    throw Error(msg)
  verbose:    ->
    return unless _options.debug
    args = Array.prototype.slice.call(arguments)
    args.unshift('[verbose]')
    console.log.apply(console, args)
  log:        -> console.log.apply(console, arguments)
  debug:      ->
    return unless _options.debug
    args = Array.prototype.slice.call(arguments)
    args.unshift('[debug]')
    console.error.apply(console, args)
}

exports.buildModuleIndex = (force = true) ->
  options = _options
  # index all modules. i.e. all folders that contains a config.yml file
  # pattern is taken from coreConfig
  configFiles = glob.sync("*/#{options.configFilePattern}")
  @_indexModules(configFiles)

exports._indexModules = (configFiles) ->
  options = _options
  modules = {}
  sortedRoutes = []

  moduleNamePattern = new RegExp(options.moduleNamePattern)

  for configFile in configFiles
    # TODO: split into methods
    moduleName = configFile.replace(/^(.+?)\/.+$/, '$1')
    @log.verbose "Found module '#{moduleName}'"
    unless moduleNamePattern.test(moduleName)
      @log.verbose("Skipping module '#{moduleName}' because it doesn't fetch the name pattern /#{options.moduleNamePattern}/")
      continue
    routesFilename = "#{moduleName}/#{options.routesFile}"
    # load config.yml
    moduleConfig = yaml.safeLoad(fs.readFileSync(configFile, options.encoding))
    _config = _.extend(_config, moduleConfig)
    moduleRoutes = null
    
    try
      fs.lstatSync(routesFilename)
    catch e
      moduleRoutes = {}

    # load routes.yml
    moduleRoutes = yaml.safeLoad(fs.readFileSync(routesFilename, options.encoding)) unless moduleRoutes
    continue unless moduleRoutes?.routes
    modules[moduleName] =
      routes: moduleRoutes
      codeFiles: glob.sync("#{moduleName}/#{options.codeFilePattern}")
 
    # first we do not sort and add all modules in order from glob
    # sorting will be done in `_sortRoutes`

    # load i18n yml
    i18nFiles = glob.sync("#{moduleName}/#{options.i18nFilePattern}")
    for i18nFile in i18nFiles
      translations = yaml.safeLoad(fs.readFileSync(i18nFile, options.encoding))
      _i18n = _.extend(_i18n, translations)
    sortedRoutes.push(moduleName)
  _modules = modules

  _sortedRoutes = @_sortRoutes(sortedRoutes)


exports._sortRoutes = (sortedRoutes) ->
  before = []
  after = []
  modules = _modules
  for moduleName of modules
    route = modules[moduleName].routes
    if route.after
      sortedRoutes.splice(sortedRoutes.indexOf(moduleName), 1) # remove element
      if route.after is '*'
        after.push(moduleName)
      else if sortedRoutes.indexOf(route.after) >= 0

        sortedRoutes.splice(sortedRoutes.indexOf(route.after)+1, 0, moduleName)
      else if after.indexOf(route.after) >= 0
        after.splice(sortedRoutes.indexOf(route.after)+1, 0, moduleName)
      else
        @log.verbose "After-module #{route.after} doesn't exists, ignoring"
    if route.before
      sortedRoutes.splice(sortedRoutes.indexOf(moduleName), 1) # remove element
      if route.before is '*'
        before.unshift(moduleName)
      else if sortedRoutes.indexOf(routs.before) >= 0
        sortedRoutes.splice(sortedRoutes.indexOf(route.before), 0, moduleName)
      else if before.indexOf(route.before) >= 0
        before.splice(sortedRoutes.indexOf(route.before)-1, 0, moduleName)
      else
        @log.verbose "Before-module #{route.before} doesn't exists, ignoring"
  
  sortedRoutes = before.concat(sortedRoutes.concat(after))

exports.getConfig = (byReference = false) ->
  if byReference then _config else _.extend({},_config)

exports.getI18N = (byReference = false) ->
  if byReference then _i18n else _.extend({},_i18n)

exports.getTranslation = exports.getI18N

exports.applyOnApp = (app) ->
  modules = _modules
  options  = _options
  for route in _sortedRoutes
    routes = modules[route].routes.routes
    codeFiles = {}
    for file in modules[route].codeFiles
      #codeFiles[]
      key = file.replace(/^.*\/([^\\]+?)\.[^\.]+?$/, '$1')
      if codeFiles[key]
        throw Error("'#{file}' is an ambigious code file to '#{codeFiles[key]}'; files with identical name are not allowed")
      codeFiles[key] = file

    routes = modules[route].routes.routes



    for url, action of routes
      urlParts = url.match(/^((post|put|get|delete|patch|all|\*)\:)*(.+)$/i)
      if urlParts
        # e.g. POST:/about
        httpMethod = urlParts[2]?.toLowerCase() or 'all'
        httpMethod = 'all' if httpMethod is options.defaultHTTPMethod
        urlRule = urlParts[3]
        # e.g. index.about (index -> code file, about -> method)
        actionParts = action.match(/^([^\.]+)\.([^\.]+)/)
        codeFile = actionParts[1]
        method = actionParts[2]
        if actionParts and codeFile and method
          # abort if code file doesnt exists
          throw Error("Cannot find file '#{codeFile}' for route '#{url}' in module '#{route}'") unless codeFiles[codeFile]
          if method
            try
              app[httpMethod](urlRule, require(options.basedir+'/'+codeFiles[codeFile])[method])
            catch e
              throw Error("Cannot find method '#{method}' in file '#{codeFile}' for route '#{url}' in module '#{route}'")

  return app
