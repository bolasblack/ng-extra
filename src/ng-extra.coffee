
angular.module('ng-extra', ['ngResource'])

.run(-> # angular.clean [[[
  angular.clean = (obj) ->
    angular.fromJson angular.toJson obj
) # ]]]

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

  ($delegate) ->
    (url, paramDefaults, actions) ->
      Resource = $delegate url, paramDefaults, actions
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
          result = Resource[method] params, data, successHandler, errorHandler
          result.$promise or result

      Resource
  ])

]) # ]]]

# html:
#   <button data-busybtn="click dblclick"
#           data-busybtn-text="submiting..."
#           data-busybtn-handler="onclick($event)"
#   >submit</button>
#
# code:
#   $scope.onclick = ->
#     defer = $q.defer()
#     # some code
#     defer.promise
#
.directive('busybtn', [ # [[[
  '$q'
  '$parse'

($q, $parse) ->
  EXPRESSION_RE = /^{{(.+)}}$/

  terminal: true
  link: (scope, element, attrs) ->
    isBusy = false
    changeMethod = if element.is('input') then 'val' else 'text'
    originalText = element[changeMethod]()

    handler = (event, params...) ->
      event.preventDefault()
      return if isBusy
      isBusy = true
      originalText = element[changeMethod]()
      fn = $parse attrs.busybtnHandler
      $q.when(fn scope, $event: event, $params: params).finally ->
        isBusy = false

    bindEvents = (eventNames) ->
      submitEvents = []
      normalEvents = []

      events = eventNames.split ' '
      for event in events
        (if /^submit\./.test(event) then submitEvents else normalEvents).push event
      element.on normalEvents.join(' '), handler

      $form = element.closest 'form'
      return unless $form.length
      $form.on submitEvents.join(' '), handler
      scope.$on '$destroy', ->
        $form.off submitEvents.join(' '), handler

    if EXPRESSION_RE.test originalText
      try
        originalText = originalText.replace EXPRESSION_RE, ($, $1) ->
          scope.$eval $1

    bindEvents attrs.busybtn

    scope.$watch (-> isBusy), ->
      element["#{if isBusy then 'add' else 'remove'}Class"] 'disabled'
      element["#{if isBusy then 'a' else 'removeA'}ttr"] 'disabled', 'disabled'
      if isBusy and angular.isDefined attrs.busybtnText
        element[changeMethod] attrs.busybtnText
      else if originalText?
        element[changeMethod] originalText
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
      result = $window[name] options.message, options.defaultText
      handler defer, result
      defer.promise

  $dialog

]) # ]]]

