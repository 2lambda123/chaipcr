/*
 * Chai PCR - Software platform for Open qPCR and Chai's Real-Time PCR instruments.
 * For more information visit http://www.chaibio.com
 *
 * Copyright 2016 Chai Biotechnologies Inc. <info@chaibio.com>
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

angular.module("canvasApp").factory('circle', [
  'ExperimentLoader',
  '$rootScope',
  'constants',
  'circleGroup',
  'outerMostCircle',
  'outerCircle',
  'centerCircle',
  'littleCircleGroup',
  'circleMaker',
  'stepDataGroup',
  'stepTemperature',
  'stepHoldTime',
  'gatherDataGroupOnScroll',
  'gatherDataCircleOnScroll',
  'gatherDataGroup',
  'gatherDataCircle',
  'previouslySelected',
  'pauseStepOnScrollGroup',
  'pauseStepCircleOnScroll',

  function(ExperimentLoader, $rootScope, Constants, circleGroup, outerMostCircle, outerCircle,
    centerCircle, littleCircleGroup, circleMaker, stepDataGroup, stepTemperature, stepHoldTime,
    gatherDataGroupOnScroll, gatherDataCircleOnScroll, gatherDataGroup, gatherDataCircle, previouslySelected,
    pauseStepOnScrollGroup, pauseStepCircleOnScroll) {
    return function(model, parentStep, $scope) {

      this.model = model;
      this.parent = parentStep;
      this.canvas = parentStep.canvas;
      this.scrollTop = 80;
      this.scrollLength = 317;
      this.halfway = (this.scrollLength - this.scrollTop) / 2;
      //this.scrollRatio = (this.scrollLength - this.scrollTop) / 100;
      this.scrollRatio1 = ((this.scrollLength - this.scrollTop) * 0.25) / 50; // 1.2;//(this.scrollLength - this.scrollTop) / 200;
      this.scrollRatio2 = ((this.scrollLength - this.scrollTop) * 0.75) / 50;//3.54;//(this.scrollLength - this.scrollTop) / 50;
      this.middlePoint = this.scrollLength - ((this.scrollLength - this.scrollTop) * 0.25); // This is the point where it reads 50

      this.gatherDataImage = this.next = this.previous = null;
      this.big = false;
      this.controlDistance = Constants.controlDistance;

      this.getLeft = function() {
        this.left = this.parent.left;
        return this;
      };

      this.getTop = function() {

        var temperature = this.model.temperature;

        if(temperature <= 50) {
          this.top = this.scrollLength - (temperature * this.scrollRatio1);
          return this;
        }

        this.top = ((this.scrollRatio2 * 100) + this.scrollTop) - (temperature * this.scrollRatio2);
        return this;
      };

      this.moveCircle = function() {
        this.getLeft();
        this.getTop();
      };

      this.moveCircleWithStep = function() {

        this.getLeft();
        this.circleGroup.set({"left": this.left + (Constants.stepWidth / 2)}).setCoords();
        this.stepDataGroup.set({"left": this.left + (Constants.stepWidth / 2)}).setCoords();
        this.gatherDataDuringRampGroup.set({"left": this.left}).setCoords();
      };

      this.setCenter = function(imgObj) {
        imgObj.originX = imgObj.originY = "center";
      };

      this.addImages = function() {

        var fabricStage = this.parent.parentStage.parent;
        // This is the image shows in the left, when gather data during ramp is enabled
        this.gatherDataImage = $.extend({}, fabricStage.imageobjects["gather-data.png"]);
        this.setCenter(this.gatherDataImage);

        this.gatherDataImageOnMoving = $.extend({}, fabricStage.imageobjects["gather-data-image.png"]);
        this.setCenter(this.gatherDataImageOnMoving);

        this.gatherDataImageMiddle = $.extend({}, fabricStage.imageobjects["gather-data.png"]);
        this.setCenter(this.gatherDataImageMiddle);
        this.gatherDataImageMiddle.setVisible(false);

        this.pauseImage = $.extend({}, fabricStage.imageobjects["pause.png"]);
        this.setCenter(this.pauseImage);

        this.pauseImageMiddle = $.extend({}, fabricStage.imageobjects["pause-middle.png"]);
        this.setCenter(this.pauseImageMiddle);
        this.pauseImageMiddle.setVisible(false);

        return this;
      };

      this.removeContents = function() {

        this.canvas.remove(this.stepDataGroup);
        this.canvas.remove(this.curve);
        this.canvas.remove(this.gatherDataOnScroll);
        this.canvas.remove(this.circleGroup);
        this.canvas.remove(this.gatherDataDuringRampGroup);

      };
      /*******************************************
        This method shows circles and gather data. Please note
        this method is invoked from canvas.js once all the stage/step are loaded.
      ********************************************/
      this.getCircle = function() {

        this.stepDataGroup.set({"left": this.left + (Constants.stepWidth / 2)}).setCoords();
        this.canvas.add(this.stepDataGroup);

        this.gatherDataCircleOnScroll = new gatherDataCircleOnScroll();
        this.gatherDataOnScroll = new gatherDataGroupOnScroll(
          [
            this.gatherDataCircleOnScroll,
            this.gatherDataImageOnMoving,
          ], this);

          this.pauseStepCircleOnScroll = new pauseStepCircleOnScroll();
          this.pauseStepOnScrollGroup = new pauseStepOnScrollGroup(
            [
              this.pauseStepCircleOnScroll,
              this.pauseImage,
            ], this);

        // enable this when image is added on creating new circle ..
        this.circleGroup.set({"left": this.left + (Constants.stepWidth / 2)}).setCoords();

        this.circleGroup.add(this.gatherDataImageMiddle);
        this.circleGroup.add(this.pauseImageMiddle);
        this.circleGroup.add(this.gatherDataOnScroll);
        this.circleGroup.add(this.pauseStepOnScrollGroup);
        this.canvas.add(this.circleGroup);

        this.gatherDataDuringRampGroup = new gatherDataGroup(
          [
            this.gatherDataCircle = new gatherDataCircle(),
            this.gatherDataImage
          ], this);


        var left = (this.previous) ? (this.left + (this.previous.left + 128)) / 2 : this.left;
        this.gatherDataDuringRampGroup.set({"left": left}).setCoords();
        this.canvas.add(this.gatherDataDuringRampGroup);
        this.showHideGatherData(this.parent.gatherDataDuringStep);
        this.controlPause(this.model.pause);
        if(this.previous) {
          this.gatherDataDuringRampGroup.setVisible(this.parent.gatherDataDuringRamp);
        }

        this.parent.adjustRampSpeedPlacing();
        this.runAlongCircle();
      };

      this.getUniqueId = function() {

        this.uniqueName = this.model.id + this.parent.parentStage.index + "circle";
        return this;
      };

      this.doThingsForLast = function(newHold, oldHold) {

        var holdTimeText = this.parent.holdDuration || this.model.hold_time;

        if(parseInt(holdTimeText) === 0) {
          this.holdTime.text = "∞";
          if(this.parent.parentStage.parent.editStageStatus === true && oldHold !== null){
            var lastStage = this.parent.parentStage;
            lastStage.dots.setVisible(false);
            this.canvas.bringToFront(lastStage.dots);
            this.parent.parentStage.parent.editModeStageChanges(this.parent.parentStage, -25, false);
            this.canvas.renderAll();
          }
        } else {
          if(oldHold !== null && parseInt(oldHold) === 0 && this.parent.parentStage.parent.editStageStatus === true) {
            this.parent.parentStage.parent.editModeStageChanges(this.parent.parentStage, 25, true);
          }
        }
      };

      this.changeHoldTime = function(new_hold) {

        /*var duration = Number(this.model.hold_time);
        var holdTimeHour = Math.floor(duration / 60);
        var holdTimeMinute = (duration % 60);

        if(holdTimeMinute < 10) {
          holdTimeMinute = "0" + holdTimeMinute;
        }*/

        this.holdTime.text = new_hold;
      };

      this.render = function() {

        this.circleGroup = new circleGroup(
          [
            this.outerCircle = new outerCircle(),
            this.circle = new centerCircle(),
            this.littleCircleGroup = new littleCircleGroup(
              [
                this.littleCircle1 = new circleMaker(-10),
                this.littleCircle2 = new circleMaker(-2),
                this.littleCircle3 = new circleMaker(6)
              ]
            )
          ], this);

        this.stepDataGroup = new stepDataGroup([
            this.temperature = new stepTemperature(this.model, this, $scope),
            this.holdTime = new stepHoldTime(this.model, this, $scope)
          ], this);

      };

      this.createNewStepDataGroup = function() {

        this.canvas.remove(this.temperature);
        this.canvas.remove(this.holdTime);

        delete(this.temperature);
        delete(this.holdTime);

        this.stepDataGroup = new stepDataGroup([
          this.temperature = new stepTemperature(this.model, this, $scope),
          this.holdTime = new stepHoldTime(this.model, this, $scope)
          ], this);

        this.canvas.add(this.stepDataGroup);
        this.canvas.renderAll();
      };

      this.makeItBig = function() {

        if(! this.big) {
          if(this.model.collect_data) {
            this.circle.setFill("#ffb400;");
            this.gatherDataImageMiddle.setVisible(false);
            if(this.gatherDataOnScroll)
              this.gatherDataOnScroll.setVisible(true);
          }

          if(this.model.pause) {
            this.circle.setFill("#ffb400");
            this.pauseImageMiddle.setVisible(false);
            this.pauseStepOnScrollGroup.setVisible(true);
          }

          this.circle.setStroke("#ffb400");
          this.outerCircle.setStroke("black");
          this.outerCircle.strokeWidth = 5;

          this.littleCircleGroup.visible = true;
          this.big = true;
        }
      };

      this.makeItSmall = function() {

        this.big = false;

        this.circle.setStroke("white");
        this.circle.setFill('#ffb400');
        this.circle.setRadius(11);
        this.circle.setStrokeWidth(8);
        this.outerCircle.setStroke(null);
        this.stepDataGroup.setVisible(true);
        this.littleCircleGroup.visible = false;

        if(this.model.collect_data) {
          this.circle.setFill("white");
          this.gatherDataImageMiddle.setVisible(true);
          this.gatherDataOnScroll.setVisible(false);
        }

        if(this.model.pause) {
          this.applyPauseChanges();
        }

      };

      this.applyPauseChanges = function() {

        this.circle.setFill("#ffb400");
        this.circle.setStroke("#ffde00");
        this.circle.strokeWidth = 4;
        this.circle.radius = 13;
        this.pauseImageMiddle.setVisible(true);
        this.gatherDataImageMiddle.setVisible(false);
        this.pauseStepOnScrollGroup.setVisible(false);
      };

      this.showHideGatherData = function(state) {

        if(state && ! this.big) {
            this.gatherDataImageMiddle.setVisible(state);
            this.circle.setFill("white");

        } else {
          this.circle.setFill("#ffb400");
          this.gatherDataOnScroll.setVisible(state);
        }
      };

      this.controlPause = function(state) {

        if(state && this.big) {
          this.pauseStepOnScrollGroup.setVisible(true);
          this.holdTime.setVisible(false);
        } else if(state) {
          this.holdTime.setVisible(false);
          this.applyPauseChanges();
        } else {
          this.pauseStepOnScrollGroup.setVisible(false);
          this.holdTime.setVisible(true);
        }
      };

      this.manageDrag = function(targetCircleGroup) {

        var top = targetCircleGroup.top;
        var left = targetCircleGroup.left;

        if(top < this.scrollTop) {
          targetCircleGroup.setTop(this.scrollTop);
          this.manageRampLineMovement(left, this.scrollTop, targetCircleGroup);
        } else if(top > this.scrollLength) {
          targetCircleGroup.setTop(this.scrollLength);
          this.manageRampLineMovement(left, this.scrollLength, targetCircleGroup);
        } else {
          this.stepDataGroup.setTop(top + 48).setCoords();
          this.manageRampLineMovement(left, top, targetCircleGroup);
        }
      };

      this.manageRampLineMovement = function(left, top, targetCircleGroup) {

        var midPointY;

        if(this.next) {

          midPointY = this.curve.nextOne(left, top);
          // We move the gather data Circle along with it [its next object's]
          this.next.gatherDataDuringRampGroup.setTop(midPointY);

          if(this.next.model.ramp.collect_data) {
            this.runAlongEdge();
          }
        }

        if(this.previous) {

          midPointY = this.previous.curve.previousOne(left, top);

          this.gatherDataDuringRampGroup.setTop(midPointY);

          if(this.model.ramp.collect_data) {
            this.runAlongCircle();
          }
        }

        this.temperatureDisplay(targetCircleGroup);
        this.parent.adjustRampSpeedPlacing();
      };

      this.temperatureDisplay = function(targetCircleGroup) {

        var dynamicTemp;
        if(targetCircleGroup.top >= this.middlePoint) {
          dynamicTemp = 50 - ((targetCircleGroup.top - this.middlePoint) / this.scrollRatio1);
        } else {
          dynamicTemp = 100 - ((targetCircleGroup.top - this.scrollTop) / this.scrollRatio2);
        }

        dynamicTemp = Math.abs(dynamicTemp).toFixed(1);
        this.temperature.text = String(dynamicTemp + "º");
        this.model.temperature = String(dynamicTemp);
      };

      this.manageClick = function() {
        //debugger;
        if(! this.big) {
          this.makeItBig();
          this.parent.parentStage.selectStage();
          this.parent.selectStep();

          if(previouslySelected.circle && (previouslySelected.circle.model.id !== this.model.id)) {
            previouslySelected.circle.makeItSmall();
          }

          previouslySelected.circle = this;
          this.canvas.renderAll();
        }
      };

      this.runAlongEdge = function() {

        this.next.gatherDataDuringRampGroup.setCoords();
        this.next.parent.rampSpeedGroup.setCoords();
        var rampEdge = this.next.parent.rampSpeedGroup.top + this.next.parent.rampSpeedGroup.height;
        if((rampEdge > this.next.gatherDataDuringRampGroup.top - 14) && this.next.parent.rampSpeedGroup.top < this.next.gatherDataDuringRampGroup.top + 16) {
          this.next.parent.rampSpeedGroup.left = this.next.parent.left + 16;
        } else {
          this.next.parent.rampSpeedGroup.left = this.next.parent.left + 5;
        }
      };

      this.runAlongCircle = function() {

        this.gatherDataDuringRampGroup.setCoords();
        this.parent.rampSpeedGroup.setCoords();
        var rampEdge = this.parent.rampSpeedGroup.top + this.parent.rampSpeedGroup.height;
        if((rampEdge > this.gatherDataDuringRampGroup.top - 14) && this.parent.rampSpeedGroup.top < this.gatherDataDuringRampGroup.top + 16) {

          var heightDifference, val;
          if(this.parent.rampSpeedGroup.top > this.gatherDataDuringRampGroup.top) {
            heightDifference = (this.parent.rampSpeedGroup.top - this.gatherDataDuringRampGroup.top);
            val = Math.sqrt(Math.abs((heightDifference * heightDifference) - 256));
            this.parent.rampSpeedGroup.left = this.parent.left + val;
          } else if (rampEdge < this.gatherDataDuringRampGroup.top) {
            heightDifference = this.gatherDataDuringRampGroup.top - rampEdge;
            val = Math.sqrt(Math.abs((heightDifference * heightDifference) - 256));
            this.parent.rampSpeedGroup.left = this.parent.left + val;
          }

        } else {
          this.parent.rampSpeedGroup.left = this.parent.left + 5;
        }
      };
    };
  }
]);
