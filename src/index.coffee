
isPromise = (obj) ->
  obj? and angular.isFunction obj.then

angular.safeModule = (moduleName, deps) ->
  depsIncludedBy = (array) ->
    includedByArray = _.partial _.contains, array
    _(deps).every includedByArray

  try
    module = angular.module moduleName
    unless depsIncludedBy module.requires
      message = "Module '#{module.name}' defined several times, but dependencies not compatible:"
      console.warn message, module.requires, ':', deps
    module
  catch
    angular.module moduleName, deps

angular.clean = (obj) ->
  angular.fromJson JSON.stringify obj, (key, value) ->
    if typeof key is 'string' and key.charAt(0) is '$' then undefined else value

angular.module('ng')

# add $safeDigest to $rootScope
.config(['$provide', ($provide) ->
  $provide.decorator('$rootScope', [
    '$delegate'
    ($delegate) ->
      $delegate.$safeDigest = ->
        @$digest() unless @$$phase
      $delegate
  ])
])

# add isPromise, isResolved, isRejected to $q
.config(['$provide', ($provide) ->
  $provide.decorator('$q', [
    '$delegate'
    ($delegate) ->
      STATUS = {
        resolved: 1
        rejected: 2
      }

      $delegate.isPromise = isPromise

      angular.forEach 'Resolved Rejected'.split(' '), (method) ->
        methodName = "is#{method}"
        $delegate[methodName] = (promise) ->
          unless isPromise(promise)
            return methodName is 'isResolved'

          # Some promise library's method
          if angular.isFunction promise[methodName]
            promise[methodName]()
          # Angular way
          else if promise.$$state?
            STATUS[method.toLowerCase()] is promise.$$state.status
          else
            $delegate[methodName] $q.when promise

      $delegate
  ])
])

angular.module('ng-extra', [])

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
.directive('busybtn', [
  '$q', '$parse', '$sce'
  ($q ,  $parse ,  $sce) ->
    link: (scope, element, attrs) ->
      isBusy = false

      elem = do ->
        changeMethod = if element.is('input') then 'val' else 'text'

        set: (content) ->
          if attrs.ngBind or attrs.ngBindTemplate
            # https://github.com/angular/angular.js/blob/0a738ce1760f38efe45e79aa133442be09b56803/src/ng/directive/ngBind.js#L66
            # https://github.com/angular/angular.js/blob/0a738ce1760f38efe45e79aa133442be09b56803/src/ng/directive/ngBind.js#L130
            element.text content
          else if attrs.ngBindHtml
            # https://github.com/angular/angular.js/blob/0a738ce1760f38efe45e79aa133442be09b56803/src/ng/directive/ngBind.js#L198
            element.html $sce.getTrustedHtml content
          else
            element[changeMethod] content

        get: ->
          bindContent = attrs.ngBind or attrs.ngBindHtml
          if bindContent
            scope.$eval bindContent
          else if attrs.ngBindTemplate
            attrs.ngBindTemplate
          else
            element[changeMethod]()

        getAttr: (attrName) ->
          element.attr("data-#{attrName}") or element.attr(attrName)

      originalText = elem.get()

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

      bindFn = if /Promise$/.test(attrs.busybtn) then bindPromise else bindEvents
      bindFn attrs.busybtn

      allBusybtnText = []
      scope.$watch (-> elem.getAttr 'busybtn-text'), (busybtnText) ->
        allBusybtnText.push busybtnText

      # Maybe your button has dynamic content?
      scope.$watch elem.get, (newVal) ->
        return if newVal in allBusybtnText
        originalText = newVal

      scope.$watch (-> isBusy), ->
        element["#{if isBusy then 'add' else 'remove'}Class"] 'disabled'
        element["#{if isBusy then 'a' else 'removeA'}ttr"] 'disabled', 'disabled'
        newestText = allBusybtnText[allBusybtnText.length - 1]
        if isBusy and angular.isDefined newestText
          elem.set newestText
        else if originalText?
          elem.set originalText
])

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
.directive('busybox', [
  '$q', '$parse'
  ($q ,  $parse) ->
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

      scope.$watch (-> isBusy), (newVal, oldVal) ->
        element["#{if isBusy then 'add' else 'remove'}Class"] 'disabled'
        element["#{if isBusy then 'a' else 'removeA'}ttr"] 'disabled', 'disabled'
        newestText = element.attr('busybox-text') or element.attr('data-busybox-text')
        if isBusy and angular.isDefined newestText
          element.val newestText
        else if ngModel
          element.val ngModel.$modelValue
])

# Wrap `window.alert`, `window.prompt`, `window.confirm`
#
# So make custom dialog component after a long time can be easier,
# with override $dialog like this: http://jsfiddle.net/hr6X4/1/
.factory('$dialog', [
  '$window', '$q'
  ($window ,  $q) ->
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
])
