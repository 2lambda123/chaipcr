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

window.ChaiBioTech.ngApp.controller('selectedNetwork', [
  '$scope',
  '$stateParams',
  'User',
  '$state',
  'NetworkSettingsService',
  '$timeout',
  function($scope, $stateParams, User, $state, NetworkSettingsService, $timeout) {

    $scope.name = $state.params.name.replace(new RegExp("_", "g"), " ");
    $scope.buttonValue = "CONNECT";
    $scope.IamConnected = false;
    $scope.statusMessage = "";
    $scope.currentNetwork = {};
    $scope.autoSetting = "auto"; // This variable controls set auto/manual.
    $scope.connectedSsid = "";
    $scope.selectedWifiNow = NetworkSettingsService.listofAllWifi[$scope.name] || null; //
    $scope.wifiNetworkType = null; // We have different settings for wep2 and wpa , so we need to look for the type of network.
    $scope.editEthernetData = {};

    $scope.$watch('autoSetting', function(val, oldVal) {
      //console.log(val, $scope);
    });

    $scope.$on('new_wifi_result', function() {

      if(NetworkSettingsService.connectedWifiNetwork.state.status === "connected") {
        $scope.statusMessage = "";
        $scope.currentNetwork = NetworkSettingsService.connectedWifiNetwork;
        $scope.editEthernetData = $scope.currentNetwork.state;
        $scope.connectedSsid = NetworkSettingsService.connectedWifiNetwork.settings["wpa-ssid"] || NetworkSettingsService.connectedWifiNetwork.settings.wireless_essid;
        $scope.connectedSsid.replace(new RegExp('"', "g"), "");
          if($state.params.name.replace(new RegExp('_', "g"), " ") === $scope.connectedSsid) {
            $scope.IamConnected = true;
          }
      } else {
        $scope.configureAsStatus(NetworkSettingsService.connectedWifiNetwork.state.status);
      }
    });

    $scope.updateConnectedWifi = function(key) {
      // When our selected wifi network is the one which is connected already.
      var wifiConnection = NetworkSettingsService.connectedWifiNetwork;
      if(wifiConnection.settings && wifiConnection.settings[key]) {
        $scope.connectedSsid = wifiConnection.settings[key].replace(new RegExp('"', "g"), "");
        if($state.params.name.replace(new RegExp('_', "g"), " ") === $scope.connectedSsid) {
          if(wifiConnection.state.status === "connected") {
            $scope.currentNetwork = wifiConnection;
            $scope.editEthernetData = $scope.currentNetwork.state;
            $scope.IamConnected = true;
            // We assign this so that, It shows data when we select
            //a wifi network which is already being connected.
          } else if (wifiConnection.state.status === "connecting") {
            $scope.buttonValue = "CONNECTING";
          }
        }
      }
    };

    $scope.connectWifi = function() {
      console.log($scope.credentials); // for checking later in 200.
      NetworkSettingsService.connectWifi($scope.credentials).then(function(data) {
        $scope.statusMessage = "";
        $scope.buttonValue = "CONNECTING";
      }, function(err) {
        console.log(err);
      });
    };

    $scope.configureAsStatus = function(status) {

      switch (status) {
        case "not_connected":
          $scope.buttonValue = "CONNECT";
          $scope.statusMessage = "";
          break;
        case "connecting":
          $scope.buttonValue = "CONNECTING";
          break;
        case "connection_error":
          $scope.buttonValue = "CONNECT";
          $scope.statusMessage = "Unable to connect";
          break;
        case "authentication_error":
          $scope.buttonValue = "CONNECT";
          $scope.statusMessage = "Authentication error";
          break;
      }
    };

    $scope.connectEthernet = function() {
      NetworkSettingsService.connectToEthernet($scope.editEthernetData).then(function(result) {
        console.log("ethernet connected", result);
      }, function(err) {
        console.log(err);
      });
    };

    $scope.init = function() {

      if($scope.selectedWifiNow) { // if our selection is a wifi network.

        try {
          if (NetworkSettingsService.connectedWifiNetwork && NetworkSettingsService.connectedWifiNetwork.state.status === "connecting") {
            $scope.connectedSsid = NetworkSettingsService.connectedWifiNetwork.settings["wpa-ssid"] || NetworkSettingsService.connectedWifiNetwork.settings.wireless_essid;
            $scope.connectedSsid.replace(new RegExp('"', "g"), "");
              if ($state.params.name.replace(new RegExp('_', "g"), " ") === $scope.connectedSsid) {
                $scope.buttonValue = "CONNECTING";
              }
          }
        } catch(err) {
          console.log("connectedWifiNetwork yet to load");
        }

        if($scope.selectedWifiNow.encryption === 'wpa2') {
          $scope.wifiNetworkType = 'wpa2';
          $scope.credentials = {
            'wpa-ssid': $scope.name,
            'wpa-psk': "",
            'type': "dhcp"
          };
          $scope.updateConnectedWifi('wpa-ssid');
        } else if($scope.selectedWifiNow.encryption === 'wep') {
          $scope.wifiNetworkType = 'wep';
          $scope.credentials = {
            'wireless_essid': $scope.name,
            'wireless_key': "",
            'type': "dhcp"
          };
          $scope.updateConnectedWifi('wireless_essid');
        }

      } else if($scope.selectedWifiNow === null && NetworkSettingsService.connectedEthernet.interface === 'eth0') { //If we selected an ethernet.
        // Configuring values if selected network is Ethernet.
        console.log("Ethernet territory");
        var ethernetConnection = NetworkSettingsService.connectedEthernet;
        if(ethernetConnection.state) {
          if($state.params.name.replace(new RegExp('_', "g"), " ") === "ethernet") {
            $scope.IamConnected = true;
            $scope.currentNetwork = ethernetConnection;
          }
        }
        // Add dns server and gateway into object if they dont exist.
        $scope.editEthernetData = $scope.currentNetwork.state;
        $scope.editEthernetData.type = $scope.currentNetwork.settings.type;

        if(! $scope.currentNetwork.state.gateway) {
          $scope.editEthernetData.gateway = '0.0.0.0';
        }

        if(! $scope.currentNetwork.state['dns-nameservers']) {
          $scope.editEthernetData['dns-nameservers'] = '0.0.0.0';
        }
      } else {
        $timeout(function() {
          $scope.selectedWifiNow = NetworkSettingsService.listofAllWifi[$scope.name] || null; //
          $scope.init();
        }, 500);
      }
    };
    $scope.init();

  }
]);
