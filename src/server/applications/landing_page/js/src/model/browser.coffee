# This class is needed to clone the browser object so that
# angular can attach its $$hashkey custom properties on the
# cloned browser object instead of on the frozen browser object
class Browser
    constructor : (browserConfig, scope, format) ->
        @api  = browserConfig
        @id   = browserConfig.getID()
        @name = browserConfig.getName()
        @editing = false
        @redirect = () ->
            curVB = cloudbrowser.currentVirtualBrowser
            curVB.redirect(browserConfig.getURL())
        @dateCreated = format.date(browserConfig.getDateCreated())
        @api.getOwners (err, owners) =>
            scope.safeApply ->
                if err then scope.setError(err)
                else @owners = owners
        @api.getReaderWriters (err, readerWriters) =>
            scope.safeApply ->
                if err then scope.setError(err)
                else @collaborators = readerWriters

    roles : [
        {
            name : 'is owner'
            , perm : 'own'
            , checkMethods : ['isOwner']
            , grantMethod : 'addOwner'
        }
        {
            name : 'can edit'
            , perm : 'readwrite'
            , checkMethods : ['isReaderWriter', 'isOwner']
            , grantMethod : 'addReaderWriter'
        }
        {
            name : 'can read'
            , perm : 'readonly'
            , checkMethods : ['isReader', 'isReaderWriter', 'isOwner']
            , grantMethod : 'addReader'
        }
    ]

    defaultRoleIndex : 1

# Exporting
this.Browser = Browser