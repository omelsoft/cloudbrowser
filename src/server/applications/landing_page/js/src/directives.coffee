Async    = require('async')
NwGlobal = require('nwglobal')

app = angular.module('CBLandingPage.directives', [])
curVB = cloudbrowser.currentVirtualBrowser
appConfig = curVB.getAppConfig()

app.directive 'cbTypeahead', () ->

    pruneList = (users, scope, callback) ->
        method  = null
        newList = []
        {shareForm} = scope
        {role, entity, collaborator} = shareForm

        Async.each users
        , (user, callback) ->
            waterfallMethods = NwGlobal.Array()
            # Dummy first method to ensure the following waterfall of methods works
            # by making the function signatures match
            waterfallMethods.push (next) -> next(null, true)

            for method in role.checkMethods
                do (method) ->
                    waterfallMethods.push (dontIncludeInList, next) ->
                        entity.api[method](user, next)
                    waterfallMethods.push (dontIncludeInList, next) ->
                        if dontIncludeInList then callback(null, false)
                        # Required for the final callback to check if it must include
                        # the user in the list or not
                        else next(null, true)

            Async.waterfall waterfallMethods, (err, include) ->
                if err
                    callback(err)
                else
                    if include then newList.push(user)
                    callback(null)
        , (err) ->
            callback(err, newList)

    return (scope, element, attrs) ->
        $(element).typeahead
            source : (query, process) ->
                Async.waterfall NwGlobal.Array(
                    (next) ->
                        appConfig.getUsers(next)
                    (users, next) ->
                        pruneList(users, scope, next)
                ), (err, users) ->
                    if err
                        scope.safeApply -> $scope.setError(err)
                    else
                        data = []
                        for user in users
                            data.push("#{user.getEmail()} (#{user.getNameSpace()})")
                        process(data)
            updater : (item) ->
                scope.$apply(attrs.ngModel + " = '#{item}'")
                return item

app.directive 'cbHasfocus', () ->
    return (scope, element, attrs) ->
        scope.$watch attrs.cbHasfocus, (nVal, oVal) ->
            if (nVal) then element[0].focus()
        element.bind 'blur', () ->
            scope.$apply(
                attrs.cbHasfocus + " = false"
                scope.browser.api.rename(scope.browser.name)
            )
        element.bind 'keydown', (e) ->
            if e.which is 13 then scope.$apply(
                attrs.cbHasfocus + " = false"
                scope.browser.api.rename(scope.browser.name)
            )