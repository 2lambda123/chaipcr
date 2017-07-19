describe("Testing StageMovementLeftService", function() {

    beforeEach(module('ChaiBioTech'));
    beforeEach(module('canvasApp'));

    var _StageMovementLeftService, _StagePositionService, _StepPositionService;

    beforeEach(inject(function(StageMovementLeftService, StagePositionService, StepPositionService) {

        _StageMovementLeftService = StageMovementLeftService;
        _StagePositionService = StagePositionService;
        _StepPositionService = StepPositionService;
    }));

    it("It should test shouldStageMoveLeft method", function() {

        sI = {
            movedStageIndex: null
        };

        spyOn(_StageMovementLeftService, "shouldStageMoveLeftCallback").and.callFake(function(thisObjs) {
            thisObjs.movedStageIndex = 5;
            return true;
        });

        _StagePositionService.allPositions = {
            
            some: function(callback, thisObjs) {
                callback(thisObjs);
            }
        };

        var rVal = _StageMovementLeftService.shouldStageMoveLeft(sI);
        expect(rVal).toEqual(5);
    });
    
    it("It should test shouldStageMoveLeft method, test shouldStageMoveLeftCallback call from this method", function() {

        sI = {
            movedStageIndex: null
        };

        spyOn(_StageMovementLeftService, "shouldStageMoveLeftCallback").and.callFake(function(thisObjs) {
            thisObjs.movedStageIndex = 5;
            return true;
        });

        _StagePositionService.allPositions = {
            
            some: function(callback, thisObjs) {
                callback(thisObjs);
            }
        };

        _StageMovementLeftService.shouldStageMoveLeft(sI);
         expect(_StageMovementLeftService.shouldStageMoveLeftCallback).toHaveBeenCalled();
    });

    it("It should test shouldStageMoveLeft method, make sure some method to have been called", function() {

        sI = {
            movedStageIndex: null
        };

        spyOn(_StageMovementLeftService, "shouldStageMoveLeftCallback").and.callFake(function(thisObjs) {
            thisObjs.movedStageIndex = 5;
            return true;
        });

        _StagePositionService.allPositions = {
            
            some: function(callback, thisObjs) {
                callback(thisObjs);
            }
        };

        spyOn(_StagePositionService.allPositions, "some");

        _StageMovementLeftService.shouldStageMoveLeft(sI);
        expect(_StagePositionService.allPositions.some).toHaveBeenCalled();
       
    });

    it("It should test shouldStageMoveLeftCallback method", function() {

        var sI = {
            movement: {
                left: 100
            },
            rightOffset: 20,
            movedLeftStageIndex: 1,
            kanvas: {
                allStageViews: [
                    {
                        moveToSide: function() {}
                    }
                ],
                allStepViews: [

                ]
            }
        };
        var args = [[50, 60, 70], 0];
        spyOn(_StagePositionService, "getPositionObject").and.returnValue(true);
        spyOn(_StagePositionService, "getAllVoidSpaces").and.returnValue(true);
        spyOn(_StepPositionService, "getPositionObject").and.returnValue(true);

        //Remember we provide this object when we call shouldStageMoveLeftCallback method
        _StageMovementLeftService.shouldStageMoveLeftCallback.apply(sI, args);

        expect(_StagePositionService.getPositionObject).toHaveBeenCalled();
        expect(_StagePositionService.getAllVoidSpaces).toHaveBeenCalled();
        expect(_StepPositionService.getPositionObject).toHaveBeenCalled();

    });

    it("It should test shouldStageMoveLeftCallback method when left is not within the area of concern", function() {

        var sI = {
            movement: {
                left: 300
            },
            rightOffset: 20,
            movedLeftStageIndex: 1,
            kanvas: {
                allStageViews: [
                    {
                        moveToSide: function() {}
                    }
                ],
                allStepViews: [

                ]
            }
        };
        var args = [[50, 60, 70], 0];
        spyOn(_StagePositionService, "getPositionObject").and.returnValue(true);
        spyOn(_StagePositionService, "getAllVoidSpaces").and.returnValue(true);
        spyOn(_StepPositionService, "getPositionObject").and.returnValue(true);

        //Remember we provide this object when we call shouldStageMoveLeftCallback method
        _StageMovementLeftService.shouldStageMoveLeftCallback.apply(sI, args);

        expect(_StagePositionService.getPositionObject).not.toHaveBeenCalled();
        expect(_StagePositionService.getAllVoidSpaces).not.toHaveBeenCalled();
        expect(_StepPositionService.getPositionObject).not.toHaveBeenCalled();

    });

    it("It should test shouldStageMoveLeftCallback method when the index is already selected", function() {

        var sI = {
            movement: {
                left: 100
            },
            rightOffset: 20,
            movedLeftStageIndex: 0,
            kanvas: {
                allStageViews: [
                    {
                        moveToSide: function() {}
                    }
                ],
                allStepViews: [

                ]
            }
        };
        var args = [[50, 60, 70], 0];
        spyOn(_StagePositionService, "getPositionObject").and.returnValue(true);
        spyOn(_StagePositionService, "getAllVoidSpaces").and.returnValue(true);
        spyOn(_StepPositionService, "getPositionObject").and.returnValue(true);

        //Remember we provide this object when we call shouldStageMoveLeftCallback method
        _StageMovementLeftService.shouldStageMoveLeftCallback.apply(sI, args);

        expect(_StagePositionService.getPositionObject).not.toHaveBeenCalled();
        expect(_StagePositionService.getAllVoidSpaces).not.toHaveBeenCalled();
        expect(_StepPositionService.getPositionObject).not.toHaveBeenCalled();

    });
});