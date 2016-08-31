(function() {
  window.App.controller('OpticalCalibrationCtrl', [
    '$scope',
    '$window',
    'Experiment',
    '$state',
    'Status',
    'GlobalService',
    'Constants',
    'host',
    '$http',
    '$interval',
    '$uibModal',
    '$rootScope',
    '$timeout',
    function OpticalCalibrationCtrl($scope, $window, Experiment, $state, Status, GlobalService, Constants,
      host, $http, $interval, $uibModal, $rootScope, $timeout) {

      var checkMachineStatusInterval = null;
      var errorModal = null;
      var pages = [
        'intro',
        'prepare-the-tubes',
        'insert-water-strips',
        'heating-and-reading-water',
        'insert-fam-strips',
        'reading-fam',
        'insert-hex-strips',
        'reading-hex',
        'analyze',
      ];

      var ERROR_TYPES = ['OFFLINE', 'CANT_CREATE_EXPERIMENT', 'CANT_START_EXPERIMENT', 'LID_OPEN', 'UNKNOWN_ERROR', 'ANOTHER_EXPERIMENT_RUNNING'];
      $scope.errors = {};
      $scope.Constants = Constants;
      $scope.created = false;
      var params;

      $scope.$on('status:data:updated', function(e, data, oldData) {
        if (!data) return;
        if (!data.experiment_controller) return;
        if (!oldData) return;
        if (!oldData.experiment_controller) return;

        $scope.data = data;
        $scope.state = data.experiment_controller.machine.state;
        $scope.timeRemaining = GlobalService.timeRemaining(data);
        $scope.isWarmingUp = data.experiment_controller.experiment? ((data.experiment_controller.experiment.step.name === 'Warm Up 75')||(data.experiment_controller.experiment.step.name === 'Warm Water')||(data.experiment_controller.experiment.step.name === 'Warm FAM')||(data.experiment_controller.experiment.step.name === 'Warm HEX')) : false;

        if ($scope.state === 'paused') {
          var pausedPages = ['heating-and-reading-water', 'reading-fam', 'reading-hex'];
          if (pausedPages.indexOf($state.current.name) > -1) {
            $scope.next();
          }
        }

        if (data.experiment_controller.experiment &&
          !$scope.experiment &&
          data.experiment_controller.experiment.name === 'Dual Channel Optical Calibration') {

          Experiment.get(data.experiment_controller.experiment.id).then(function(resp) {
            $scope.experiment = resp.data.experiment;
          });
        }

        var this_exp_id = $scope.experiment? $scope.experiment.id : null;
        var running_exp_id = oldData.experiment_controller.experiment? oldData.experiment_controller.experiment.id : null;
        var is_current_exp = parseInt(this_exp_id) === parseInt(running_exp_id) && !!running_exp_id;

        if ($scope.state === 'idle' && (oldData.experiment_controller.machine.state !== 'idle') &&  is_current_exp) {
          // experiment is complete
          Experiment.get($scope.experiment.id).then(function (resp) {
            $scope.experiment = resp.data.experiment;
            params = {id: $scope.experiment.id};
            if( $scope.experiment.completion_status !== 'success') {
              $state.go('analyze', params);
            }
            else {
              $scope.analyzeExperiment();

            }
          });
        }
      });

      function checkMachineStatus() {
        Status
          .fetch()
          .then(function(deviceStatus) {
            // In case connected

            if (errorModal) {
              errorModal.close();
              errorModal = null;
            }

            var this_exp_id = $scope.experiment? $scope.experiment.id : null;
            var running_exp_id = deviceStatus.experiment_controller.experiment? deviceStatus.experiment_controller.experiment.id : null;
            var is_current_exp = (running_exp_id !== null) && parseInt(this_exp_id) === parseInt(running_exp_id);

            if (deviceStatus.experiment_controller.machine.state !== 'idle' && !is_current_exp) {
              $scope.errors['ANOTHER_EXPERIMENT_RUNNING'] = "Another experiment is running.";
            } else {
              delete $scope.errors['ANOTHER_EXPERIMENT_RUNNING'];
            }

            if ($scope.errors['OFFLINE']) {
              delete $scope.errors['OFFLINE'];
            }

            if (deviceStatus.optics.lid_open === "true" || deviceStatus.optics.lid_open === true) { // lid is open
              $scope.errors.LID_OPEN = "Close lid to begin.";
            } else {
              delete $scope.errors['LID_OPEN'];
            }
          })
          .catch(function(err) {
            // Error
            $scope.errors['OFFLINE'] = "Can't connect to the machine.";

            if (err.status === 500) {

              if (!errorModal) {
                var scope = $rootScope.$new();
                scope.message = {
                  title: "Cant connect to machine.",
                  body: err.data.errors || "Error"
                };

                errorModal = $uibModal.open({
                  templateUrl: './views/modal-error.html',
                  scope: scope
                });
              }
            }
          });
      }

      checkMachineStatusInterval = $interval(checkMachineStatus, 1000);

      $scope.analyzeExperiment = function () {
        Experiment.analyze($scope.experiment.id)
        .then(function (resp) {
          if(resp.status == 202){
            $timeout($scope.analyzeExperiment, 1000);
          }
          else {
            $state.go('analyze', params);
            $scope.result = resp.data;
            $scope.valid = true;
            for (var i = resp.data.valid.length - 1; i >= 0; i--) {
              if (resp.data.valid[i] === false) {
                $scope.valid = false;
                break;
              }
            }
            if($scope.valid)
              $http.put(host + '/settings', {settings: {"calibration_id": $scope.experiment.id}});
          }

        })
        .catch(function (resp) {
          if(resp.status == 503){
            $timeout($scope.analyzeExperiment, 1000);
          }
          else{
            $state.go('analyze', params);
          }
        });

      }

      $scope.lidHeatPercentage = function() {
        if (!$scope.experiment) return 0;
        if (!$scope.data) return 0;
        return ($scope.data.lid.temperature / $scope.experiment.protocol.lid_temperature);
      };

      $scope.blockHeatPercentage = function() {
        var blockHeat = $scope.getHeatBlockTemp();
        if (!blockHeat) return 0;
        if (!$scope.experiment) return 0;
        return ($scope.data.heat_block.temperature / blockHeat);
      };

      $scope.getHeatBlockTemp = function() {
        if(!$scope.data) return 0;
        if(!$scope.data.heat_block) return 0;
        if(!$scope.data.heat_block.zone1) return 0;
        if(!$scope.data.heat_block.zone2) return 0;
        var temp = ($scope.data.heat_block.zone1.temperature*1 + $scope.data.heat_block.zone2.temperature*1) / 2;
        var target = ($scope.data.heat_block.zone1.target_temperature*1 + $scope.data.heat_block.zone2.target_temperature*1) / 2;
        return {
          temperature: temp,
          target: target
        };
      };

      $scope.next = function() {
        debugger;
        var pageIndex = pages.indexOf($state.current.name);
        var params = {};
        if( pageIndex === (pages.length - 1))
          params.id = $scope.experiment.id;

        $state.go(pages[pageIndex + 1], params);
      };

      $scope.createExperiment = function() {
        if(!$scope.created) {
          Experiment.create({ guid: 'dual_channel_optical_cal_v2' })
            .then(function(resp) {
              Experiment.startExperiment(resp.data.experiment.id)
                .then(function() {
                  $scope.experiment = resp.data.experiment;
                  $scope.created = true;
                  $scope.errors = {};
                  $scope.next();
                })
                .catch(function(resp) {
                  $scope.errors.CANT_START_EXPERIMENT = "Can't start experiment.";
                });
            })
            .catch(function(err) {
              $scope.errors.CANT_CREATE_EXPERIMENT = "Unable to create experiment.";
            });
        }
      };

      $scope.resumeExperiment = function() {
        Experiment.resumeExperiment().then(function() {
          $scope.next();
        });
      };

      $scope.cancelExperiment = function() {
        Experiment.stopExperiment($scope.experiment_id).then(function() {
          var redirect = '/#/settings/';
          $window.location = redirect;
        });
      };

      $scope.isCollectingData = function() {
        if (!$scope.data) return false;
        if (!$scope.data.optics) return false;
        return ($scope.data.optics.collect_data === 'true');
      };

      $scope.currentStep = function() {
        if (!$scope.experiment) return;
        if (!$scope.data) return;
        if (!$scope.data.experiment_controller) return;
        if (!$scope.data.experiment_controller.experiment) return;
        // var step_id = parseInt($scope.data.experiment_controller.experiment.step.id);
        var step_number = parseInt($scope.data.experiment_controller.experiment.step.number);
        return step_number;
        // if (!step_id) return;
        // return $scope.experiment.protocol.stages[0].stage.steps[step_id - 1].step;

      };

      $scope.finalStepHoldTime = function() {
        if (!$scope.experiment) return 0;
        if (!$scope.data) return 0;
        if (!$scope.data.experiment_controller) return 0;
        if (!$scope.data.experiment_controller.experiment) return 0;

        var steps = $scope.experiment.protocol.stages[0].stage.steps;
        return steps[steps.length - 1].step.hold_time || 0;
      };

      $scope.getErrors = function () {
        var errors = [];
        for (var i = ERROR_TYPES.length - 1; i >= 0; i--) {
          if($scope.errors[ERROR_TYPES[i]])
            errors.push($scope.errors[ERROR_TYPES[i]]);
        }
        return errors;
      };

    }
  ]);
})();
