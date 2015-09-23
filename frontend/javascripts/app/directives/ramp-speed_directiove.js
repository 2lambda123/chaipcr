window.ChaiBioTech.ngApp.directive('rampSpeed', [
  'ExperimentLoader',
  '$timeout',
  'alerts',

  function(ExperimentLoader, $timeout, alerts) {
    return {
      restric: 'EA',
      replace: true,
      scope: {
        caption: "@",
        unit: "@",
        reading: '='
      },
      templateUrl: 'app/views/directives/edit-value.html',

      link: function(scope, elem, attr) {

        scope.edit = false;
        scope.delta = true; // This is to prevent the directive become disabled, check delta in template, this is used for auto delta field

        scope.$watch("reading", function(val) {

          if(angular.isDefined(scope.reading)) {
            console.log(Number(scope.reading));

            if(Number(scope.reading) <= 0) {
              scope.shown = "AUTO";
              scope.unit = "";
            } else {
              scope.shown = scope.reading;
              scope.unit = "C/s";
            }
            //scope.shown = (Number(scope.reading) === 0) ? "AUTO" : scope.reading;
            scope.hidden = Number(scope.reading);
          }
        });


        scope.editAndFocus = function(className) {
          scope.edit = ! scope.edit;
          $timeout(function() {
            $('.' + className).focus();
          });
        };

        scope.save = function() {

          scope.edit = false;
          if(! isNaN(scope.hidden) && Number(scope.hidden) < 1000) {
            //if(Number(scope.hidden) < 1000) {
              scope.reading = Math.abs(Number(scope.hidden));
              $timeout(function() {
                ExperimentLoader.changeRampSpeed(scope.$parent).then(function(data) {
                  console.log(data);
                });
              });
              return ;
            //}
          }
          scope.hidden = scope.reading;
          var warningMessage = alerts.rampSpeedWarning;
          scope.$parent.showMessage(warningMessage);
        };
      }
    };
  }
]);
