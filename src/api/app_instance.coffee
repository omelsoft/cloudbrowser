Async   = require('async')
Browser = require('./browser')
User    = require('../server/user')
cloudbrowserError = require('../shared/cloudbrowser_error')

# Permission checks are included wherever possible and a note is made if
# missing. Details like name, id, url etc. are available to everybody.

###*
    The application instance has been shared with another user
    @event AppInstance#share
###
###*
    The current application instance has been renamed
    @event AppInstance#rename
    @type {String}
###
###*
    API for application instance (internal class).
    @class AppInstance
    @param {Object}         options 
    @param {User}           options.userCtx     The current user.
    @param {AppInstance}    options.appInstance The application instance.
    @param {Cloudbrowser}   options.cbCtx       The cloudbrowser API object.
    @fires AppInstance#share
    @fires AppInstance#rename
###
class AppInstance

    # Private Properties inside class closure
    _pvts = []

    constructor : (options) ->
        # Defining @_idx as a read-only property
        Object.defineProperty(this, "_idx", {value : _pvts.length})

        {cbServer, appInstance, cbCtx, userCtx} = options

        if not cbServer?
            console.log "error"
            err = new Error()
            console.log err.stack

        _pvts.push
            cbServer : cbServer
            cbCtx       : cbCtx
            userCtx     : userCtx
            appInstance : appInstance

        # Freezing the prototype to protect from unauthorized changes
        # by people using the API
        Object.freeze(this.__proto__)
        Object.freeze(this)

    ###*
        Gets the ID of the application state.
        @method getID
        @return {Number}
        @instance
        @memberOf AppInstance
    ###
    getID : () ->
        return _pvts[@_idx].appInstance.id

    ###*
        Gets the name of the application state.
        @method getName
        @return {String}
        @instance
        @memberOf AppInstance
    ###
    getName : () ->
        {appInstance} = _pvts[@_idx]
        # This name is actually a number
        name = appInstance.name
        return name

    ###*
        Creates a browser associated with the current application instance.
        @method createBrowser
        @param {browserCallback} callback
        @instance
        @memberOf AppInstance
    ###
    createBrowser : (callback) ->
        {cbServer, userCtx, cbCtx, appInstance} = _pvts[@_idx]
        # Permission checking is done inside call to createBrowser
        # in the application instance and in the browser manager
        Async.waterfall [
            (next) ->
                appInstance.createBrowser(userCtx, next)
            (bserver, next) ->
                next(null, new Browser({
                    browser : bserver
                    userCtx : userCtx
                    cbCtx   : cbCtx
                    cbServer : cbServer
                }))
        ], callback

    ###*
        Gets the date of creation of the application instance.
        @method getDateCreated
        @return {Date}
        @instance
        @memberOf AppInstance
    ###
    getDateCreated : () ->
        return _pvts[@_idx].appInstance.dateCreated

    ###*
        Closes the appInstance.
        @method close
        @param {errorCallback} callback
        @instance
        @memberof AppInstance
    ###
    close : (callback) ->
        {cbServer, appInstance, userCtx} = _pvts[@_idx]
        {appInstances} = appInstance.app
        
        appInstance.close(userCtx, callback)

    ###*
        Gets the owner of the application instance.
        @method getOwner
        @instance
        @memberof AppInstance
    ###
    getOwner : () ->
        {appInstance, cbCtx} = _pvts[@_idx]
        # No permission check done as users may need to know
        # the owner of an app instance when they are associated
        # with a browser of the app instance but not with the 
        # app instance itself
        return appInstance.owner

    ###*
        Registers a listener for an event on the appInstance.
        @method addEventListener
        @param {String} event
        @param {appInstanceEventCallback} callback 
        @instance
        @memberof AppInstance
    ###
    addEventListener : (event, callback) ->
        if typeof callback isnt "function" then return

        validEvents = ["rename", "share"]
        if typeof event isnt "string" or validEvents.indexOf(event) is -1
            return

        {appInstance, userCtx} = _pvts[@_idx]

        # Only users associated with the app instance can listen
        # on its events
        if @isAssocWithCurrentUser() then switch(event)
            when "rename"
                appInstance.on(event, callback)
            when "share"
                appInstance.on(event, (user) -> callback(user.getEmail()))

    ###*
        Checks if the current user has some permissions associated with the 
        current appInstance (readwrite, own)
        @method isAssocWithCurrentUser
        @return {Bool}
        @instance
        @memberof AppInstance
    ###
    isAssocWithCurrentUser : () ->
        {appInstance, userCtx} = _pvts[@_idx]

        if @isOwner(userCtx._email)
            return true
        if @isReaderWriter(userCtx._email)
            return true
        
        return false


    ###*
        Gets all users that have the permission to read and
        write to the application instance.
        @method getReaderWriters
        @return {Bool}
        @instance
        @memberof AppInstance
    ###
    getReaderWriters : () ->
        {appInstance} = _pvts[@_idx]

        if @isAssocWithCurrentUser()
            users = []
            users.push(rw._email) for rw in appInstance.readerwriters
            return users

    ###*
        Checks if the user is a reader-writer of the instance.
        @method isReaderWriter
        @param {String} emailID
        @return {Bool} 
        @instance
        @memberof AppInstance
    ###
    isReaderWriter : (emailID) ->
        {appInstance} = _pvts[@_idx]

        if typeof emailID isnt "string" then return

        for i in appInstance.readerwriters
            if i._email is userCtx._email
                return true
        return false


    ###*
        Checks if the user is the owner of the application instance
        @method isOwner
        @param {String} user
        @return {Bool} 
        @instance
        @memberof AppInstance
    ###
    isOwner : (user) ->
        {appInstance} = _pvts[@_idx]

        if typeof user isnt "string" then return

        return user is appInstance.owner._email
        

    ###*
        Grants the user readwrite permissions on the application instance.
        @method addReaderWriter
        @param {String} emailID 
        @param {errorCallback} callback 
        @instance
        @memberof AppInstance
    ###
    addReaderWriter : (emailID, callback) ->
        {cbServer, appInstance, userCtx} = _pvts[@_idx]
        
        permissionManager = cbServer.permissionManager

        if typeof emailID isnt "string"
            return callback?(cloudbrowserError("PARAM_INVALID", "- emailID"))

        user = new User(emailID)

        Async.waterfall [
            (next) =>
                if appInstance.owner._email isnt userCtx._email
                    next(cloudbrowserError("PERM_DENIED"))
                else if appInstance.owner._email is user._email
                    next(cloudbrowserError("IS_OWNER"))
                else permissionManager.addAppInstancePermRec
                    user          : user
                    mountPoint    : appInstance.app.mountPoint
                    permission    : 'readwrite'
                    appInstanceID : appInstance.id
                    callback      : (err) -> next(err)
            (next) ->
                appInstance.addReaderWriter(user, next)
        ], (err, next) ->
            callback(err)
            

    ###*
        Get the application instance JavaScript object that can be used
        by the application and that is serialized and stored in the database.
        This is only called when the appInstance is a local object.
        @method getObj
        @return {Object} Custom object, the details of which are known only
        to the application code itself
        @instance
        @memberof AppInstance
    ###
    getObj : () ->
        {appInstance, userCtx} = _pvts[@_idx]
        # if appInstance.isOwner(userCtx) or appInstance.isReaderWriter(userCtx)
        return appInstance.getObj()

    ###*
        Gets the url of the application instance.
        @method getURL
        @return {String}
        @instance
        @memberOf AppInstance
    ###
    getURL : () ->
        {currentBrowser} = _pvts[@_idx].cbCtx
        appConfig = currentBrowser.getAppConfig()
        appURL    = appConfig.getUrl()

        return "#{appURL}/application_instance/#{@getID()}"

module.exports = AppInstance
