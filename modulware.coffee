yaml = require 'js-yaml'
glob = require 'glob'
fs   = require 'fs'
path = require 'path'
_    = require 'underscore'
_.mixin(require('underscore.nested'))

doesFileExists = fs.lstatSync

class Modulware

  config: {
    themeDir: -> @options.themeDir
  }

  options        : {}
  modules        : {}
  i18n           : {}
  sortedRoutes   : []
  globOptions    : {}

  options: {
    configFilePattern: 'config.@(yml|yaml)'
    routesFile: 'routes.yml'
    codeFilePattern: 'code/**/*.@(coffee|js)'
    i18nFilePattern: 'i18n/**/*.@(yml|yaml)'
    viewFolderPattern: 'views/'#'views/*.@(jade)'
    themesFolder: 'themes'
    themeDir: ''
    theme: ''
    defaultHTTPMethod: '*' # can be get|put|post|delete|patch|all|*(is for all)
    debug: true
    encoding: 'utf8'
    moduleNamePattern: '^[a-zA-Z\\_\\-0-9]+$'
    basedir: null # with `null` => process.cwd()
    configOnLocals: true
    optionsOnLocals: true
    defaultMountpoint: '/' # is able to contain a $module variable, e.g. '/$module'
    localConfigKey: 'settings.config'
    localOptionKey: 'settings.options'
    routesYMLMandatory: true
    verbosity: 0
    expressjs:
      set:
        'view engine': 'jade'
  }

  constructor: (options = {}, app = null) ->
    if typeof options is 'function'
      app = options
      options = {}
    @options        = _.extend({}, @options, options)
    @modules        = _.extend({}, @module)
    @i18n           = _.extend({}, @i18n)
    @sortedRoutes   = _.extend({}, @sortedRoutes)
    @globOptions    = _.extend({}, @globOptions)
    @setOptions(options)
    @applyOnExpress(app) if typeof app is 'function'
    @

  _replaceVariableHolder: (haystack, needle, replacement) ->
    haystack.replace(new RegExp("\\$#{needle}([^\\w]+.*|)$", "g"), replacement+'$1')
  _replaceModuleVariable: (str, moduleName, needle = 'module') ->
    @_replaceVariableHolder(str, needle, moduleName)
  _replaceThemeVariable: (str, moduleName, needle = 'theme') ->
    @_replaceVariableHolder(str, needle, moduleName)

  getOptions: -> @options

  setOptions: (options) ->
    # apply options over default options
    _.extendOwn(@options, {}, @options, options)
    @options.basedir ?= process.cwd()
    @globOptions = {
      cwd: @options.basedir
    }
    @options

  getModules: -> @modules

  applyOnExpress: (instanceMethod) ->
    return @logError('instanceMethod argument needs to be a function') if typeof instanceMethod isnt 'function'
    @buildModuleIndex()
    app = @_applyOnInstanceMethod(instanceMethod)
    _.setNested(app.locals, @options.localConfigKey, @getConfig()) if @options.configOnLocals
    _.setNested(app.locals, @options.localOptionKey, @getOptions()) if @options.optionsOnLocals
    return app

  
  logError:      ->
      args = Array.prototype.slice.call(arguments)
      args.unshift('[error]')
      console.error.apply(console, args)
  logFatalError: (msg) ->
      args = Array.prototype.slice.call(arguments)
      args.unshift('[fatalError]')
      console.error.apply(console, args)
      throw Error(msg)
  logVerbose:    ->
      return unless /verbose/i.test(@options.verbosity)
      args = Array.prototype.slice.call(arguments)
      args.unshift('[verbose]')
      console.log.apply(console, args)
  log:           -> console.log.apply(console, arguments)
  logDebug:      ->
      return unless /debug/i.test(@options.verbosity)
      args = Array.prototype.slice.call(arguments)
      args.unshift('[debug]')
      console.error.apply(console, args)

  buildModuleIndex: (force = true) ->
    options = @options
    # index all modules. i.e. all folders that contains a config.yml file
    # pattern is taken from coreConfig
    configFiles = glob.sync("*/#{options.configFilePattern}", @globOptions)
    @_indexModules(configFiles)

  _indexModules: (configFiles) ->
    options = @options
    modules = {}
    sortedRoutes = []

    moduleNamePattern = new RegExp(options.moduleNamePattern)

    # index modules + sort out "invalid" modules (i.e. neither containing config.yml nor routes.yml)
    for configFile in configFiles
      # TODO: split into methods
      moduleName = configFile.replace(/^(.+?)\/.+$/, '$1')
      unless moduleNamePattern.test(moduleName)
        @logVerbose("Skipping module '#{moduleName}' because it doesn't fetch the name pattern /#{options.moduleNamePattern}/")
        continue
      if options.routesYMLMandatory
        path = @makePathAbsolute("#{moduleName}/#{options.routesFile}")
        try
          doesFileExists(path)
        catch e
          @logVerbose("Skipping module '#{moduleName}' because it doesn't contain a '#{options.routesFile}'") # " ('#{path}') ")
          continue
      
      @logVerbose "Added module '#{moduleName}'"
      
      modules[moduleName] =
        configFile: configFile

    modules = @_indexConfigurationFilesOfModules(modules)
    for moduleName in modules
      sortedRoutes.push(moduleName)
    # sort routes
    @sortedRoutes = @_sortRoutes(sortedRoutes, modules)

  makePathAbsolute: (path) ->
    "#{@options.basedir}/#{path?.replace(/^[\\\/]+/,'')}"

  _indexConfigurationFilesOfModules: (modules) ->
    options = @options
    # read config
    for moduleName of modules
      module = modules[moduleName]

      # load config.yml
      moduleConfig = yaml.safeLoad(fs.readFileSync(@makePathAbsolute(module.configFile), options.encoding))
      _config = _.extend(@config, moduleConfig)
      
      moduleRoutes = null
    # read routes
    for moduleName of modules
      module = modules[moduleName]
      routesFilename = "#{moduleName}/#{options.routesFile}"

      try
        doesFileExists(@makePathAbsolute(routesFilename))
      catch e
        moduleRoutes = {}

      # load routes.yml
      modules[moduleName].routing = {}
      moduleRoutes = yaml.safeLoad(fs.readFileSync(@makePathAbsolute(routesFilename), options.encoding))# unless moduleRoutes
      #continue unless moduleRoutes?.routes
      modules[moduleName].routing = moduleRoutes or {}
      modules[moduleName].codeFiles = glob.sync("#{moduleName}/#{options.codeFilePattern}", @globOptions)
      # first we do not sort and add all modules in order from glob
      # sorting will be done in `_sortRoutes`
    # read i18n translation files
    for moduleName of modules
      module = modules[moduleName]
      # load i18n yml
      i18nFiles = glob.sync("#{moduleName}/#{options.i18nFilePattern}", @globOptions)
      for i18nFile in i18nFiles
        translations = yaml.safeLoad(fs.readFileSync(@makePathAbsolute(i18nFile), options.encoding))
        @i18n = _.extend(@i18n, translations)

    @modules = modules


  _sortRoutes: (sortedRoutes, modules) ->
    before = []
    after = []
    for moduleName of modules
      route = modules[moduleName].routing
      if route.after
        sortedRoutes.splice(sortedRoutes.indexOf(moduleName), 1) # remove element
        if route.after is '*'
          after.push(moduleName)
        else if sortedRoutes.indexOf(route.after) >= 0

          sortedRoutes.splice(sortedRoutes.indexOf(route.after)+1, 0, moduleName)
        else if after.indexOf(route.after) >= 0
          after.splice(sortedRoutes.indexOf(route.after)+1, 0, moduleName)
        else
          @logVerbose "After-module #{route.after} doesn't exists, ignoring"
      if route.before
        sortedRoutes.splice(sortedRoutes.indexOf(moduleName), 1) # remove element
        if route.before is '*'
          before.unshift(moduleName)
        else if sortedRoutes.indexOf(routs.before) >= 0
          sortedRoutes.splice(sortedRoutes.indexOf(route.before), 0, moduleName)
        else if before.indexOf(route.before) >= 0
          before.splice(sortedRoutes.indexOf(route.before)-1, 0, moduleName)
        else
          @logVerbose "Before-module #{route.before} doesn't exists, ignoring"
      else
        sortedRoutes.push(moduleName)

    return before.concat(sortedRoutes.concat(after))

  getConfig: (byReference = true) ->
    if byReference then @config else _.extend({}, @config)

  getI18N: (byReference = false) ->
    if byReference then @i18n else _.extend({}, @i18n)

  getTranslation: @getI18N

  _applyOnInstanceMethod: (instanceMethod) ->
    modules = @modules
    options  = @options
    
    mountToApp = (Boolean) typeof instanceMethod is 'function' and instanceMethod?.name is 'createApplication'

    themeTemplates = []
    if options.themesFolder
      theme = options.theme || ''
      theme = theme.replace(/[\\//]+$/,'').replace(/^[\\//]+/,'')
      options.themeDir = "#{options.themesFolder.replace(/[\\//]+$/,'')}/#{theme}/#{options.viewFolderPattern}"

      themeTemplates = glob.sync(options.themeDir, @globOptions)

    if mountToApp
      mainApp = instanceMethod()
    else
      app = instanceMethod

    # now all routes will be applied to the app
    # in order of `before:` and `after:`

    
    #@logDebug(@sortedRoutes,  JSON.stringify(modules))

    for moduleName in @sortedRoutes
      # if we deal with express instance method
      # we create a new express / app instance for each module
      if mountToApp
        app = instanceMethod()
        for settingKey of options.expressjs?.set
          app.set(settingKey, options.expressjs.set[settingKey])
      
      views = []

      routes = modules[moduleName].routing.routes
      codeFiles = {}
      for file in modules[moduleName].codeFiles
        #codeFiles[]
        key = file.replace(/^.*\/([^\\]+?)\.[^\.]+?$/, '$1')
        if codeFiles[key]
          throw Error("'#{file}' is an ambigious code file to '#{codeFiles[key]}'; files with identical name are not allowed")
        codeFiles[key] = file

      routes = modules[moduleName].routing.routes

      for urlString, action of routes
        # you can have multiple urls (comma seperated), like
        # GET:/home,POST:/home
        urls = urlString.split(',')
        for url in urls
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
              throw Error("Cannot find file '#{codeFile}' for route '#{url}' in module '#{moduleName}'") unless codeFiles[codeFile]
              if method
                try
                  app[httpMethod](urlRule, require(options.basedir+'/'+codeFiles[codeFile])[method])
                catch e
                  throw Error("Cannot find method '#{method}' in file '#{codeFile}' for route '#{url}' in module '#{moduleName}'")

      # apply views
      viewFiles = glob.sync("#{moduleName}/#{options.viewFolderPattern}", @globOptions)
      views.push(viewFiles[0]) if viewFiles?.length > 0

      #app.set('views',path.dirname(viewFiles[0])) if viewFiles?.length > 0

      # mount to (parent/main) app
      if mountToApp
        mountpoint = if @getConfig()[moduleName]?.mountpoint then @getConfig()[moduleName]?.mountpoint else options.defaultMountpoint
        mountpoint = @_replaceVariableHolder(mountpoint, moduleName)
        mainApp.use(mountpoint, app)

      views.push(themeTemplates[0]) if themeTemplates?.length > 0

      app.set('views', views)

    return if mountToApp
      mainApp
    else
      app


module.exports = Modulware

  
