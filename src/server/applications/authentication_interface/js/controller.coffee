CBAuthentication = angular.module("CBAuthentication", [])

CBAuthentication.controller "LoginCtrl", ($scope) ->

    $scope.email            = null
    $scope.password         = null
    $scope.emailError       = null
    $scope.loginError       = null
    $scope.resetSuccessMsg  = null
    $scope.isDisabled       = false
    $scope.showEmailButton  = false
    currentVirtualBrowser   = cloudbrowser.getCurrentVirtualBrowser()
    appConfig               = currentVirtualBrowser.getAppConfig()
    googleStrategy          = appConfig.getGoogleStrategy()
    localStrategy           = appConfig.getLocalStrategy()

    $scope.$watch "email + password", ->
        $scope.loginError       = null
        $scope.isDisabled       = false
        $scope.resetSuccessMsg  = null
    
    $scope.$watch "email", ->
        $scope.emailError = null

    $scope.googleLogin = () -> googleStrategy.login()

    $scope.login = () ->

        if not $scope.email or not $scope.password
            $scope.loginError = "Please provide both the Email ID and the password to login"

        else
            $scope.isDisabled = true
            localStrategy.login
                user     : new cloudbrowser.app.User($scope.email, 'local')
                password : $scope.password
                callback : (success) ->
                    if not success
                        $scope.$apply -> $scope.loginError = "Invalid Credentials"
                    $scope.isDisabled = false

    $scope.sendResetLink = () ->

        if !$scope.email? or not /^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,4}$/.test $scope.email.toUpperCase()
            $scope.emailError = "Please provide a valid email ID"

        else
            $scope.resetDisabled = true
            appConfig.sendResetLink new cloudbrowser.app.User($scope.email, 'local'), (success) ->
                if success
                    $scope.resetSuccessMsg = "A password reset link has been sent to your email ID."
                else
                    $scope.$apply ->
                        $scope.emailError = "This email ID is not registered with us."
                $scope.$apply ->
                    $scope.resetDisabled = false

CBAuthentication.controller "SignupCtrl", ($scope) ->
    $scope.email            = null
    $scope.password         = null
    $scope.vpassword        = null
    $scope.emailError       = null
    $scope.signupError      = null
    $scope.passwordError    = null
    $scope.successMessage   = false
    $scope.isDisabled       = false
    currentVirtualBrowser   = cloudbrowser.getCurrentVirtualBrowser()
    appConfig               = currentVirtualBrowser.getAppConfig()
    googleStrategy          = appConfig.getGoogleStrategy()
    localStrategy           = appConfig.getLocalStrategy()

    $scope.$watch "email", (nval, oval) ->
        $scope.emailError       = null
        $scope.signupError      = null
        $scope.isDisabled       = false
        $scope.successMessage   = false

        appConfig.isUserRegistered new cloudbrowser.app.User($scope.email, 'local'), (exists) ->
            if exists then $scope.$apply ->
                $scope.emailError = "Account with this Email ID already exists!"
                $scope.isDisabled = true

    $scope.$watch "password+vpassword", ->
        $scope.signupError      = null
        $scope.passwordError    = null
        $scope.isDisabled       = false

    $scope.googleLogin = () -> googleStrategy.signup()

    $scope.signup = ->
        $scope.isDisabled = true

        if !$scope.email? or !$scope.password?
            $scope.signupError = "Must provide both Email and Password!"

        else if not /^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,4}$/.test $scope.email.toUpperCase()
            $scope.emailError = "Not a valid Email ID!"

        else if not /^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[^\da-zA-Z])\S{8,15}$/.test $scope.password
            $scope.passwordError = "Password must be have a length between 8 - 15 characters," +
            " must contain atleast 1 uppercase, 1 lowercase, 1 digit and 1 special character." +
            " Spaces are not allowed."
        else
            localStrategy.signup
                user     : new cloudbrowser.app.User($scope.email, 'local')
                password : $scope.password
                callback : () ->
                    $scope.$apply -> $scope.successMessage = true