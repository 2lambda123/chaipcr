(function() {
  angular.module('dynexp.chai-test')
  .controller('ChaiTestExpRunningCtrl', [
    '$scope',
    '$window',
    'dynexpExperimentService',
    '$state',
    '$stateParams',
    'Status',
    'dynexpGlobalService',
    'host',
    '$http',
    '$timeout',
    '$rootScope',
    '$uibModal',
    'focus',
    function ChaiTestExpRunningCtrl($scope, $window, Experiment, $state, $stateParams, Status, GlobalService,
      host, $http, $timeout, $rootScope, $uibModal, focus) {

      $window.$('body').addClass('pika-exp-running-active');
      $scope.$on('$destroy', function() {
        $window.$('body').removeClass('pika-exp-running-active');
      });

      $scope.state = '';
      $scope.old_state = '';
      var enterState = false;
      var INIT_LOADING = 2;
      $scope.statusLoading = INIT_LOADING;

      function getExperiment(exp_id, cb) {
        Experiment.get(exp_id).then(function(resp) {
          $scope.experiment = resp.data.experiment;
          $rootScope.pageTitle = $scope.experiment.name + " | Open qPCR";
          if (cb) cb(resp.data.experiment);
        });
      }

      function getId() {
        if ($stateParams.id) {
          $scope.experimentId = $stateParams.id;
          getExperiment($scope.experimentId, function(exp){
            $scope.initial_done = true;
          });
        } else {
          $timeout(function() {
            getId();
          }, 500);
        }
      }
      getId();
      
      $scope.checkExperimentStatus = function() {
        Experiment.get($scope.experimentId).then(function(resp) {
          $scope.experiment = resp.experiment;
          if ($scope.experiment.completed_at) {
            if ($scope.experiment.completion_status === 'success') {
              $scope.goToResults();
            }
          } else {
            $timeout($scope.checkExperimentStatus, 1000);
          }
        });
      };

      $scope.$on('status:data:updated', function(e, data, oldData) {
        if (!data) return;
        if (!data.experiment_controller) return;
        if (!oldData) return;
        if (!oldData.experiment_controller) return;

        $scope.data = data;
        $scope.state = data.experiment_controller.machine.state;
        $scope.old_state = oldData.experiment_controller.machine.state;
        $scope.timeRemaining = GlobalService.timeRemaining(data);
        $scope.stateName = $state.current.name;

        if (
          $scope.state === 'idle' && 
          $scope.old_state === 'idle' && 
          ($state.current.name === 'coronavirus-env.experiment-running' || $state.current.name === 'covid19-surv.experiment-running')) {
          getExperiment($scope.experimentId, function(exp){
            if ( $scope.statusLoading > 0 ){
              $scope.statusLoading--;
            } else {
              switch($scope.experiment.guid){
                case 'chai_coronavirus_env_kit':
                  if ($scope.experiment.completion_status) {
                    $state.go('coronavirus-env.experiment-result', { id: $scope.experiment.id });
                  } else {
                    $state.go('coronavirus-env.set-wells', { id: $scope.experiment.id });
                  }
                  break;
                case 'chai_covid19_surv_kit':
                  if ($scope.experiment.completion_status) {
                    $state.go('covid19-surv.experiment-result', { id: $scope.experiment.id });
                  } else {
                    $state.go('covid19-surv.set-wells', { id: $scope.experiment.id });
                  }
                  break;
              }              
            }
          });
        }
      });
    }
  ]);
})();
