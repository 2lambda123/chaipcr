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

angular.module("canvasApp").factory('mouseMove', [
  'ExperimentLoader',
  'previouslySelected',
  'previouslyHoverd',
  'scrollService',
  function(ExperimentLoader, previouslySelected, previouslyHoverd, scrollService) {

    this.init = function(C, $scope, that) {

      var me, left, canvasContaining = $('.canvas-containing'), startPos;

      this.canvas.on("mouse:move", function(evt) {

        if(that.mouseDown && evt.target) {

          if(that.startDrag === 0) {
            that.canvas.defaultCursor = "ew-resize";
            that.startDrag = evt.e.clientX;
            startPos = canvasContaining.scrollLeft();
          }

          left = startPos - (evt.e.clientX - that.startDrag); // Add startPos to reverse the moving direction.

          if((left >= 0) && (left <= $scope.scrollWidth - 1024)) {

            $scope.$apply(function() {
              $scope.scrollLeft = left;
            });

            canvasContaining.scrollLeft(left);
          }
        }
      });
    };
    return this;
  }
]);
