class Session
  set: (user) ->
    window.localStorage.setItem "user", user
  get: -> window.localStorage.getItem "user"
  delete: -> window.localStorage.removeItem "user"
  exists: -> window.localStorage.getItem("user") != null

class TabletUser extends Backbone.Model

  url: 'user'

  RECENT_USER_MAX: 3

  initialize: ( options ) ->
    @myRoles = []

  # This may be overriden by Tangerine.settings.attributes.userSchema as loaded in 
  # on boot.applySettings().
  schema:
    name: "Text"
    password:
      type: "Password"
      validators: [
        { type: 'match', field: 'passwordConfirm', message: 'Passwords must match!' }
      ]
    passwordConfirm:
      type: "Password"
      validators: [{
        type: 'match',
        field: 'password',
        message: 'Passwords must match!'
      }]

  # Never save the passwordConfirm.
  beforeSave: ->
    delete this.attributes.passwordConfirm
    # TODO: The fact we have to set a field to password and not pass and that we get that weird PouchDB error when we do it the right way need
    # to be figured out. This is spaghetti right now with the dance between password and pass.
    delete this.attributes.password

  ###
    Accessors
  ###
  name:        -> @get("name") || null
  roles:       -> @getArray("roles")
  isAdmin:     -> "_admin" in @roles()
  recentUsers: -> Tangerine.settings.getArray("recentUsers")

  ###
    Mutators
  ###
  setPassword: ( pass ) ->

    if pass is ""
      @trigger "pass-error", "Password cannot be empty"

    hashes = TabletUser.generateHash(pass)
    salt = hashes['salt']
    pass = hashes['pass']

    @set
      "pass" : pass
      "salt" : salt

    return @

  setId : (name) -> 
    @set
      "_id"  : TabletUser.calcId(name)
      "name" : name

  ###
    Static methods
  ###

  @calcId: (name) -> "user-#{name}"

  @generateHash: ( pass, salt ) ->
    salt = hex_sha1(""+Math.random()) if not salt?
    pass = hex_sha1(pass+salt)
    return {
      pass : pass
      salt : salt
    }


  ###
    helpers
  ###

  setPreferences: ( domain = "general", key = '', value = '' ) ->
    preferences = @get("preferences") || {}
    preferences[domain] = {} unless preferences[domain]?
    preferences[domain][key] = value
    @save("preferences": preferences)

  getPreferences: ( domain = "general", key = "" ) ->
    prefs = @get("preferences")
    return prefs?[domain] || null if key is ""
    return prefs?[domain]?[key] || null

  verifyPassword: ( providedPass ) ->
    salt     = @get "salt"
    realHash = @get "pass"
    testHash = TabletUser.generateHash( providedPass, salt )['pass']
    return testHash is realHash

  ###
    controller type
  ###

  ghostLogin: (user, pass) ->
    Tangerine.log.db "User", "ghostLogin"
    location = encodeURIComponent(window.location.toString())
    document.location = Tangerine.settings.location.group.url.replace(/\:\/\/.*@/,'://')+"_ghost/#{user}/#{pass}/#{location}"


  signup: ( name, pass, attributes, callbacks={} ) =>
    @set "_id" : TabletUser.calcId(name)
    @fetch
      success: => @trigger "name-error", "User already exists."
      error: =>
        @set "name" : name
        @setPassword pass
        @save attributes,
          success: =>
            @login name, pass
            @trigger "login"
            callbacks.success?()

  login: ( name, pass, callbacks = {} ) ->

    if Tangerine.session.exists()
      @trigger "name-error", "User already logged in"
    
    if _.isEmpty(@attributes) or @get("name") isnt name
      @setId name
      @fetch
        success : =>
          @attemptLogin pass, callbacks
        error : (a, b) ->
          Utils.midAlert "User does not exist."
    else
      @attemptLogin pass, callbacks

  attemptLogin: ( pass, callbacks={} ) ->
    if @verifyPassword pass
      Tangerine.session.set @id
      @trigger "login"
      console.log (@id + ' session has started.')
      callbacks.success?()
      
      recentUsers = @recentUsers().filter( (a) => !~a.indexOf(@name()))
      recentUsers.unshift(@name())
      recentUsers.pop() if recentUsers.length > @RECENT_USER_MAX
      Tangerine.settings.save "recentUsers" : recentUsers

      return true
    else
      @trigger "pass-error", t("LoginView.message.error_password_incorrect")
      Tangerine.session.delete()
      callbacks.error?()
      return false

  sessionRefresh: (callbacks) ->
    if Tangerine.session.exists()
      @set "_id": Tangerine.session.get()
      @fetch
        error: ->
          callbacks.error?()
        success: ->
          callbacks.success()
    else
      callbacks.success()

  # @callbacks Supports isAdmin, isUser, isAuthenticated, isUnregistered
  verify: ( callbacks ) ->
    if @name() == null
      if callbacks?.isUnregistered?
        callbacks.isUnregistered()
      else
        Tangerine.router.navigate "login", true
    else
      callbacks?.isAuthenticated?()
      if @isAdmin()
        callbacks?.isAdmin?()
      else
        callbacks?.isUser?()

  logout: ->

    @clear()

    Tangerine.session.delete()

    Tangerine.router.navigate "login", true

    Tangerine.log.app "User-logout", "logout"
