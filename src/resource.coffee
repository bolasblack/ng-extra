
angular.module('ng-extra.resource', ['ngResource'])

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
            return unless method in ['POST', 'PUT', 'PATCH']
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
