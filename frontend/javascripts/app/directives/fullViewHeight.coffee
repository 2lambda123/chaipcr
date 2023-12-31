App.directive 'fullViewHeight', [
  'WindowWrapper'
  '$timeout'
  (WindowWrapper, $timeout) ->

    restrict: 'AE',
    scope:
      offset: '=?'
      force: '=?'
      doc: '=?'
      parent: '=?'
      min: '=?'
    link: ($scope, elem) ->

      $scope.offset = ($scope.offset || 0) * 1
      $scope.min = ($scope.min || 0) * 1

      elem.addClass 'full-height'
      getHeight = ->
        height = if $scope.doc
                  WindowWrapper.documentHeight() - $scope.offset
                else if $scope.parent
                  elem.parent().height() - $scope.offset
                else
                  WindowWrapper.height() - $scope.offset

        if height > elem.parent().height()  then height = elem.parent().height()
        height = if $scope.min > height then $scope.min else height
        height
        
      set = (height) ->
        height = height || getHeight()

        if ($scope.force)
          elem.css( 'height':  height )
          elem.css( 'min-height' : height )
        else
          # height = if elem.height() > height then elem.height() else height
          elem.css( 'min-height' : height )
          
      resizeTimeout = null

      $scope.$on 'window:resize', ->
        height = getHeight()
        elem.css('min-height': height, height: '', overflow: 'hidden')
        if resizeTimeout
          $timeout.cancel(resizeTimeout)

        resizeTimeout = $timeout ->
          elem.css(overflow: '', height: '', 'min-height': '')
          set()
          resizeTimeout = null
        , 100

      if $scope.min > 0
        set($scope.min)

      $timeout(set, 100)

]