
isPromise = (obj) ->
  obj? and angular.isFunction obj.then

angular.module('ng-extra', ['ngResource'])

.run(-> # angular.clean [[[
  angular.clean = (obj) ->
    angular.fromJson angular.toJson obj
) # ]]]

.run([ # [[[ $scope.$watchOnce
  '$rootScope'

($rootScope) ->
  $rootScope.$watchOnce = (watchExpression, listener, objectEquality) ->
    deregistrater = $rootScope.$watch watchExpression, ->
      deregistrater()
      listener?.apply? this, arguments...
    , objectEquality

  $rootScope.$watchCollectionOnce = (watchExpression, listener) ->
    deregistrater = $rootScope.$watchCollection watchExpression, ->
      deregistrater()
      listener?.apply? this, arguments...
]) # ]]]

.run([ # [[[ $scope.$safeDigest
  '$rootScope'

($rootScope) ->
  $rootScope.$safeDigest = ->
    @$digest() unless @$$phase
]) # ]]]

.config([ # Resource.wrapStaticMethod [[[
  '$provide'

($provide) ->
  $provide.decorator('$resource', [
    '$delegate'

  ($delegate) ->
    (url, paramDefaults, actions) ->
      Resource = $delegate url, paramDefaults, actions

      Resource.wrapStaticMethod = (fnName, fn, deleteInstanceMethod = true) ->
        originalFn = Resource[fnName]
        if deleteInstanceMethod
          delete Resource::["$#{fnName}"]
        Resource[fnName] = fn -> originalFn.apply Resource, arguments

      Resource
  ])
]) # ]]]


# Resource = $resource(
#   '/path/to/resource',
#   {id: '@defaultId'},
#   {
#     action1: {
#       normalize: true
#       retainprops: ['id', 'name']
#     }
#   }
# )
#
# resource = new Resource
# resource.$update(params, data)
#
.config([ # Resource action normalize [[[
  '$provide'

($provide) ->
  $provide.decorator('$resource', [
    '$delegate'

  ($resource) ->
    (url, paramDefaults, actions) ->
      Resource = $resource url, paramDefaults, actions
      angular.forEach actions, (options, method) ->
        return unless options.normalize
        retainprops = options.retainprops ? ['id']

        Resource::["$#{method}"] = (params, data, success, error) ->
          if angular.isFunction params
            error = data
            success = params
            params = {}
            data = {}
          else if angular.isFunction data
            error = success
            success = data
            data = {}

          data = angular.copy(data) or {}
          angular.forEach retainprops, (property) =>
            data[property] = this[property]

          successHandler = (resp, headers) =>
            @$resolved = true
            angular.copy angular.clean(resp), this
            success? this, headers
          errorHandler = (resp) ->
            @$resolved = true
            error? resp

          @$resolved = false
          Resource[method](params, data, successHandler, errorHandler).$promise.then => this

      Resource
  ])

]) # ]]]

# html:
#   <button data-busybtn="click dblclick"
#           data-busybtn-text="submiting..."
#           data-busybtn-handler="onclick($event)"
#   >submit</button>
#
#   <!-- promise variable must end with 'Promise' -->
#   <button data-busybtn="clickPromise"
#           data-busybtn-text="submiting..."
#   >submit</button>
#
# code:
#   $scope.onclick = ->
#     defer = $q.defer()
#     # some code
#     defer.promise # return a promise
#
#   $scope.onclick2 = ->
#     defer = $q.defer()
#     $scope.clickPromise = defer.promise # assign a promise
#     # some code
#
.directive('busybtn', [ # [[[
  '$q'
  '$parse'

($q, $parse) ->
  link: (scope, element, attrs) ->
    isBusy = false
    changeMethod = if element.is('input') then 'val' else 'text'
    originalText = element[changeMethod]()

    handler = (event, params...) ->
      event.preventDefault()
      return if isBusy
      isBusy = true
      fn = $parse attrs.busybtnHandler
      $q.when(fn scope, $event: event, $params: params).finally ->
        isBusy = false

    bindEvents = (eventNames) ->
      submitEvents = []
      normalEvents = []

      events = eventNames.split ' '
      for event in events
        (if /^submit(\.|$)?/.test(event) then submitEvents else normalEvents).push event
      element.on normalEvents.join(' '), handler

      $form = element.closest 'form'
      return unless $form.length
      $form.on submitEvents.join(' '), handler
      scope.$on '$destroy', ->
        $form.off submitEvents.join(' '), handler

    bindPromise = (promiseName) ->
      scope.$watch promiseName, (promise) ->
        return unless isPromise promise
        isBusy = true
        promise.finally ->
          isBusy = false

    # Maybe your button content is dynamic?
    scope.$watch (-> element[changeMethod]()), (newVal) ->
      return if newVal is attrs.busybtnText
      originalText = newVal

    bindFn = if /Promise$/.test(attrs.busybtn) then bindPromise else bindEvents
    bindFn attrs.busybtn

    scope.$watch (-> isBusy), ->
      element["#{if isBusy then 'add' else 'remove'}Class"] 'disabled'
      element["#{if isBusy then 'a' else 'removeA'}ttr"] 'disabled', 'disabled'
      if isBusy and angular.isDefined attrs.busybtnText
        element[changeMethod] attrs.busybtnText
      else if originalText?
        element[changeMethod] originalText
]) # ]]]

# html:
#   <input type="text"
#          data-ng-model="somevar"
#          data-busybox="keypress"
#          data-busybox-text="submiting..."
#          data-busybox-handler="oninput($event)"
#          value="submit" />
#
#   <!-- promise variable must end with 'Promise' -->
#   <input data-ng-model="somevar"
#          data-ng-keypress="oninput2($event)"
#          data-busybox="inputPromise"
#          data-busybox-text="submiting..."
#          value="submit" />
#   >
#
# code:
#   $scope.oninput = ($event) ->
#     defer = $q.defer()
#     # some code
#     defer.promise # return a promise
#
#   $scope.oninput2 = ($event) ->
#     defer = $q.defer()
#     $scope.inputPromise = defer.promise # assign a promise
#     # some code
#
.directive('busybox', [ # [[[
  '$q'
  '$parse'

($q, $parse) ->
  terminal: true
  require: '?ngModel'
  link: (scope, element, attrs, ngModel) ->
    isBusy = false

    bindPromise = (promiseName) ->
      scope.$watch promiseName, (promise) ->
        return unless isPromise promise
        isBusy = true
        promise.finally ->
          isBusy = false

    bindEvents = (eventNames) ->
      element.on eventNames, (event, params...) ->
        return if isBusy
        isBusy = true
        fn = $parse attrs.busyboxHandler
        $q.when(fn scope, $event: event, $params: params).finally ->
          isBusy = false

    bindFn = if /Promise$/.test(attrs.busybox) then bindPromise else bindEvents
    bindFn attrs.busybox

    scope.$watch (-> isBusy), ->
      element["#{if isBusy then 'add' else 'remove'}Class"] 'disabled'
      element["#{if isBusy then 'a' else 'removeA'}ttr"] 'disabled', 'disabled'
      if isBusy and angular.isDefined attrs.busyboxText
        element.val attrs.busyboxText
      else if ngModel
        element.val ngModel.$modelValue
]) # ]]]

# Wrap `window.alert`, `window.prompt`, `window.confirm`
#
# So make custom dialog component after a long time can be easier,
# with override $dialog like this: http://jsfiddle.net/hr6X4/1/
.factory('$dialog', [ # [[[
  '$window'
  '$q'

($window, $q) ->
  $dialog = {}

  methods =
    alert: (defer, result) ->
      defer.resolve()
    confirm: (defer, result) ->
      deferMethod = if result then 'resolve' else 'reject'
      defer[deferMethod] result
    prompt: (defer, result) ->
      deferMethod = if result? then 'resolve' else 'reject'
      defer[deferMethod] result

  angular.forEach methods, (handler, name) ->
    $dialog[name] = (options) ->
      defer = $q.defer()
      result = $window[name] options.message, options.defaultText ? ''
      handler defer, result
      defer.promise

  $dialog

]) # ]]]

