angular.module("canvasApp").factory('stepTemperature', [
  function() {
    return function(model, parent) {

      this.model = model;
      this.parent = parent;
      this.canvas = parent.canvas;
      this.stepData = this.model;

      this.render = function() {
        var temp = parseFloat(this.stepData.temperature);
        temp = (temp < 100) ? temp.toFixed(1) : temp;

        this.text = new fabric.Text(temp +"º", {
          fill: 'black',
          fontSize: 20,
          top : this.parent.top + 10,
          left: this.parent.left - 15,
          fontFamily: "dinot-bold",
          selectable: false
        });

      };

      this.render();
      return this.text;
    };
  }
]);
