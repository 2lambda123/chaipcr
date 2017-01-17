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

window.ChaiBioTech.ngApp.service('alerts', [
  function() {

    return {
      noOfCyclesWarning: "The value you have entered is less than AUTO DELTA START CYCLE. Please enter a value greater than AUTO DELTA START CYCLE or reduce AUTO DELTA START CYCLE and re-enter value.",
      nonDigit: "You have entered a wrong value. Please make sure you enter digits in the format HH:MM:SS.",
      autoDeltaOnWrongStage: "You can't turn on auto delta on this stage. Please select a CYCLING STAGE to enable auto delat.",
      startOnCycleWarning: "The value you have entered is greater than the number of cycles set for this stage. Please enter a value lower than the number of cycles or increase the number of cycles for this stage.",
      startOnCycleMinimum: "The minimum value you can enter is 1 please input a value greater than zero.",
      rampSpeedWarning: "Please enter a valid integer value in the range 0 - 6 .",
      holdDurationZeroWarning: "Plese enter a non zero value, Only last step with collect_data turned off, can be assigned with infinite hold.",
      internalServerError: "There is an internal server error pleas re-load the page",
      autoDeltaTemp: "Please enter a value in the range [-99 To 99]"
    };
  }
]);
