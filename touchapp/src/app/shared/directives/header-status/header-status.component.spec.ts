import { Component } from '@angular/core';
import { CommonModule } from '@angular/common';
import {
  TestBed,
  async,
  inject
} from '@angular/core/testing';
import {
  HttpModule,
  XHRBackend
} from '@angular/http';
import {
  MockConnection,
  MockBackend
} from '@angular/http/testing';
import { Router } from '@angular/router';
import ngStyles from 'ng-style';

import { AuthHttp } from '../../services/auth_http/auth_http.service';
import { StatusService } from '../../../services/status/status.service';
import { ExperimentService } from '../../../services/experiment/experiment.service';
import { HeaderStatusComponent } from './header-status.component';
import { ExperimentMockInstance } from '../../models/experiment.model.mock';
import { StatusDataMockInstance } from '../../models/status.model.mock';
import { mockStatusReponse } from '../../../services/status/mock-status-response';
import { WindowRef } from '../../services/windowref/windowref.service';
import { initialStatusData } from '../../../services/status/initial-status-data';
import { HrMinSecPipe } from '../../pipes/hr-min-secs/hr-min-secs.pipe';

let getExperimentCB: any = null;
let expUpdatesCB: any = null;
const ExperimentServiceMock = {
  $updates: {
    subscribe: (cb) => {
      expUpdatesCB = cb;
    },
    next: (e) => {
      if (expUpdatesCB) expUpdatesCB(e)
    }
  },
  getExperiment: () => {
    return {
      subscribe: (cb) => {
        getExperimentCB = cb;
      }
    }
  },
  startExperiment: () => {},
  getAmplificationData: () => {
    return {
      subscribe: () => {}
    }
  }
}
const mockRouter = {
  navigate: () => {}
}

@Component({
  template: `<div chai-header-status [experiment-id]="id"></div>`
})
class TestingComponent {
  public id: number
}

describe('HeaderStatusComponent Directive', () => {

  let statusData: any;
  let exp: any;

  beforeEach(async(() => {

    spyOn(ExperimentServiceMock, 'getExperiment').and.callThrough()
    exp = JSON.parse(JSON.stringify(ExperimentMockInstance));
    statusData = JSON.parse(JSON.stringify(StatusDataMockInstance))

    TestBed.configureTestingModule({
      imports: [
        CommonModule,
        HttpModule
      ],
      declarations: [
        TestingComponent,
        HeaderStatusComponent,
        HrMinSecPipe
      ],
      providers: [
        {
          provide: ExperimentService, useValue: ExperimentServiceMock
        },
        {
          provide: Router, useValue: mockRouter
        },
        WindowRef,
        StatusService,
        AuthHttp
      ]
    }).compileComponents()

  }))

  it('should show loading initially', inject(
    [ExperimentService],
    (expService: ExperimentService) => {

      let fixture = TestBed.createComponent(TestingComponent);
      let component = fixture.componentInstance;
      fixture.detectChanges();
      expect(ExperimentServiceMock.getExperiment).not.toHaveBeenCalled();
      expect(fixture.debugElement.nativeElement.querySelector('.exp-name').innerHTML.trim()).toBe('Loading...')
      component.id = exp.id;
      fixture.detectChanges();
      expect(ExperimentServiceMock.getExperiment).toHaveBeenCalledWith(component.id);
      getExperimentCB(exp);
      fixture.detectChanges();
      expect(fixture.debugElement.nativeElement.querySelector('.exp-name').innerHTML.trim()).toBe(exp.name)

    }))

  it('should not show messages when status data has not arrived yet', inject(
    [StatusService],
    (statusService: StatusService) => {
      let fixture = TestBed.createComponent(TestingComponent)
      fixture.componentInstance.id = exp.id
      fixture.detectChanges()
      getExperimentCB(exp)
      statusService.$data.next(initialStatusData)
      fixture.detectChanges()
      let el = fixture.debugElement.nativeElement
      expect(el.querySelector('.message')).toBeFalsy()

    }
  ))

  describe('When status is idle', () => {

    beforeEach(async(() => {
      //statusData = JSON.parse(JSON.stringify(StatusDataMockInstance))
      statusData.experiment_controller.machine.state = "idle"
    }))

    describe('When experiment has not been started', () => {

      beforeEach(async(() => {
        exp = JSON.parse(JSON.stringify(ExperimentMockInstance))
        exp.started_at = null;
        exp.completed_at = null;
        statusData.experiment_controller.experiment.id = null
      }))

      it('should not start experiment when lid is open', inject(
        [StatusService],
        (statusService: StatusService) => {
          statusData.optics.lid_open = true
          this.fixture = TestBed.createComponent(TestingComponent)
          this.fixture.componentInstance.id = exp.id
          this.fixture.detectChanges()
          getExperimentCB(exp)
          this.fixture.detectChanges()
          statusService.$data.next(statusData)
          this.fixture.detectChanges()
          let el = this.fixture.debugElement.nativeElement
          expect(el.querySelector('.message-text').innerHTML.trim()).toBe('LID IS OPEN')
          expect(el.querySelector('.button').classList.contains('disabled')).toBe(true)
        }))

      describe('When experiment is valid', () => {

        beforeEach(inject(
          [StatusService],
          (statusService: StatusService) => {
            statusData.optics.lid_open = false
            this.fixture = TestBed.createComponent(TestingComponent)
            this.fixture.componentInstance.id = exp.id
            this.fixture.detectChanges()
            getExperimentCB(exp)
            this.fixture.detectChanges()
            statusService.$data.next(statusData)
            this.fixture.detectChanges()
          }))

        it('should start experiment when lid is closed', async(() => {
          let el = this.fixture.debugElement.nativeElement
          expect(el.querySelector('.button').innerHTML.trim()).toBe('START EXPERIMENT')
        }
        ))

        it('should show confirm start experiment', async(() => {
          let el = this.fixture.debugElement.nativeElement
          el.querySelector('.button').click()
          this.fixture.detectChanges()
          expect(el.querySelector('.button').innerHTML.trim()).toBe('CONFIRM START')
        }))

        it('should start experiment upon confirmation', inject(
          [ExperimentService, Router],
          (expService: ExperimentService, router) => {

            spyOn(router, 'navigate').and.callThrough()

            spyOn(expService, 'startExperiment').and.callFake(() => {
              return {
                subscribe: (cb) => {
                  if(cb) cb()
                }
              }
            })

            let el = this.fixture.debugElement.nativeElement
            //click start button
            el.querySelector('.button').click()
            this.fixture.detectChanges()
            // click confirm button
            el.querySelector('.button').click()
            this.fixture.detectChanges()
            expect(expService.startExperiment).toHaveBeenCalledWith(exp.id)
            expect(expService.getExperiment).toHaveBeenCalledTimes(2)
            expect(router.navigate).toHaveBeenCalledWith(['/charts', 'exp', exp.id, 'amplification'])

          }
        ))

        afterEach(() => {
          let bgCon = this.fixture.debugElement.nativeElement.querySelector('.bg-placeholder')
          expect(bgCon.getAttribute('style')).toBe('')
          expect(bgCon.classList.contains('completed')).toBe(false)
        })

      })

    })

    describe('When experiment is complete', () => {

      beforeEach(inject(
        [ExperimentService],
        (expService: ExperimentService) => {
          let subscribeSpy = jasmine.createSpy('getAmplificationDataSubscribeSpy')
          spyOn(expService, 'getAmplificationData').and.returnValue({
            subscribe: subscribeSpy
          })
          exp.id = 1;
          expect(exp.started_at).toBeTruthy();
          expect(exp.completed_at).toBeTruthy();

          this.fixture = TestBed.createComponent(TestingComponent);
          this.fixture.componentInstance.id = exp.id;
          this.fixture.detectChanges();
          getExperimentCB(exp);
          this.fixture.detectChanges();
          expect(expService.getAmplificationData).toHaveBeenCalledWith(exp.id)
          expect(subscribeSpy).toHaveBeenCalled()

        }
      ))

      it('should NOT show completed experiment if completion_status is aborted', inject(
        [ExperimentService, StatusService],
        (expService: ExperimentService, statusService: StatusService) => {

          exp.completion_status = "aborted"

          statusService.$data.next(statusData)
          this.fixture.detectChanges();
          expService.$updates.next(`experiment:completed:${exp.id}`)
          this.fixture.detectChanges()
          let el = this.fixture.debugElement.nativeElement.querySelector('.status-indicator > .message');
          expect(el.innerHTML.trim()).not.toBe('COMPLETED')
          expect(this.fixture.debugElement.nativeElement.querySelector('.bg-placeholder').classList.contains('completed')).toBe(true)

        }))

      it('should show analyzing experiment', inject(
        [ExperimentService, StatusService],
        (expService: ExperimentService, statusService: StatusService) => {

          exp.completion_status = 'success';

          statusService.$data.next(statusData)
          this.fixture.detectChanges();
          let el = this.fixture.debugElement.nativeElement.querySelector('.status-indicator .message-text');
          expect(el.innerHTML.trim()).toBe('RUN COMPLETE, ANALYZING...')
          expect(this.fixture.debugElement.nativeElement.querySelector('.bg-placeholder').classList.contains('completed')).toBe(false)

        }))

      it('should show experiment completed', inject(
        [ExperimentService, StatusService],
        (expService: ExperimentService, statusService: StatusService) => {
          exp.completion_status = "success"

          statusService.$data.next(statusData)
          this.fixture.detectChanges();
          expService.$updates.next(`experiment:completed:${exp.id}`)
          this.fixture.detectChanges();
          let el = this.fixture.debugElement.nativeElement.querySelector('.status-indicator > .message');
          expect(el.innerHTML.trim()).toBe('COMPLETED')
          expect(this.fixture.debugElement.nativeElement.querySelector('.bg-placeholder').classList.contains('completed')).toBe(true)


        }
      ))


    })

    describe('When experiment failed', () => {

      beforeEach(() => {

        expect(exp.started_at).toBeTruthy();

        this.fixture = TestBed.createComponent(TestingComponent);
        this.fixture.componentInstance.id = ExperimentMockInstance.id;
        this.fixture.detectChanges();

      })

      it('should show user cancelled', inject(
        [StatusService, ExperimentService],
        (statusService: StatusService, expService: ExperimentService) => {

          exp.completion_status = 'aborted';
          exp.completed_at = new Date()

          getExperimentCB(exp);
          this.fixture.detectChanges();
          statusService.$data.next(statusData);
          this.fixture.detectChanges();
          expService.$updates.next(`experiment:completed:${exp.id}`)
          this.fixture.detectChanges()
          let el = this.fixture.debugElement.nativeElement.querySelector('.status-indicator .message-text');
          let failedEl = this.fixture.debugElement.nativeElement.querySelector('.status-indicator .failed');

          expect(failedEl.innerHTML.trim()).toBe('FAILED');
          expect(el.innerHTML.trim()).toContain('USER CANCELLED');
        }
      ))


      it('should NOT show an error occured', inject(
        [ExperimentService, StatusService],
        (expService: ExperimentService, statusService: StatusService) => {

          exp.completed_at = new Date()
          exp.completion_message = "";
          exp.completion_status = 'success';

          getExperimentCB(exp);
          this.fixture.detectChanges();

          statusService.$data.next(statusData);
          this.fixture.detectChanges();
          expService.$updates.next(`experiment:completed:${exp.id}`)
          this.fixture.detectChanges()

          let failedEl = this.fixture.debugElement.nativeElement.querySelector('.status-indicator .failed');
          expect(failedEl).toBeFalsy();
        }
      ))


      it('should show an error occured', inject(
        [ExperimentService, StatusService],
        (expService: ExperimentService, statusService: StatusService) => {

          exp.completed_at = new Date()
          exp.completion_message = "";
          exp.completion_status = 'some error';

          getExperimentCB(exp);
          this.fixture.detectChanges();

          statusService.$data.next(statusData);
          this.fixture.detectChanges();
          expService.$updates.next(`experiment:completed:${exp.id}`)
          this.fixture.detectChanges()

          let el = this.fixture.debugElement.nativeElement.querySelector('.status-indicator .message-text');
          let failedEl = this.fixture.debugElement.nativeElement.querySelector('.status-indicator .failed');
          expect(failedEl.innerHTML.trim()).toBe('FAILED');
          expect(el.innerHTML.trim()).toContain('AN ERROR OCCURED');
        }
      ))

    })

  })

  describe('When experiment is running', () => {

    beforeEach(async(() => {
      statusData.experiment_controller.machine.state = "running";
    }))

    //it('should subscribe to experiment service updates', inject(
    //  [ExperimentService, StatusService],
    //  (expService:ExperimentService, statusService:StatusService) => {

    //    spyOn(expService.$updates, 'subscribe').and.callThrough();

    //    statusData.experiment_controller.experiment.id = exp.id;

    //    this.fixture = TestBed.createComponent(TestingComponent);
    //    // it should not subscribe when expid is null
    //    statusService.$data.next(statusData);
    //    this.fixture.detectChanges();
    //    expect(expService.$updates.subscribe).not.toHaveBeenCalled()

    //    // it shoud subscribe when exp id is present and current is current experient running
    //    this.fixture.componentInstance.id = exp.id;
    //    this.fixture.detectChanges();
    //    statusService.$data.next(statusData);
    //    this.fixture.detectChanges();
    //    expect(expService.$updates.subscribe).toHaveBeenCalled();
    //  }
    //))

    //it('should NOT subscribe to experiment service updates if not current experiment', inject(
    //  [ExperimentService, StatusService],
    //  (expService:ExperimentService, statusService:StatusService) => {

    //    spyOn(expService.$updates, 'subscribe').and.callThrough();

    //    statusData.experiment_controller.experiment.id = 9876;

    //    this.fixture = TestBed.createComponent(TestingComponent);
    //    // it should not subscribe when expid is null
    //    statusService.$data.next(statusData);
    //    this.fixture.detectChanges();
    //    expect(expService.$updates.subscribe).not.toHaveBeenCalled()

    //    // it shoud subscribe when exp id is present and current is current experient running
    //    this.fixture.componentInstance.id = exp.id;
    //    this.fixture.detectChanges();
    //    statusService.$data.next(statusData);
    //    this.fixture.detectChanges();
    //    expect(expService.$updates.subscribe).not.toHaveBeenCalled();
    //  }
    //))

    describe('When experiment is in lead heating state', () => {
      beforeEach(async(() => {
        statusData.experiment_controller.machine.state = "lid_heating"
        statusData.experiment_controller.machine.thermal_state = "idle"
        statusData.experiment_controller.experiment.id = exp.id

        exp.started_at = "2017-08-30T16:30:13.000Z";
        exp.completed_at = null;

        this.fixture = TestBed.createComponent(TestingComponent);
        this.fixture.componentInstance.id = exp.id;
        this.fixture.detectChanges();

      }))

      it('should display estimating remaining time', inject(
        [StatusService],
        (statusService: StatusService) => {

          getExperimentCB(exp)
          this.fixture.detectChanges()
          statusService.$data.next(statusData)
          this.fixture.detectChanges()
          let el = this.fixture.debugElement.nativeElement

          expect(el.querySelector('.message-text > span').innerHTML.trim()).toBe('IN PROGRESS...')
          expect(el.querySelector('.message-text > strong').innerHTML.trim()).toBe('ESTIMATING TIME REMAINING')

        }
      ))

    })

    describe('When experiment is done loading and heating', () => {

      beforeEach(async(() => {
        statusData.experiment_controller.machine.state = "running"
        statusData.experiment_controller.machine.thermal_state = "running"
        statusData.experiment_controller.experiment.id = exp.id

        exp.started_at = "2017-08-30T16:30:13.000Z";
        exp.completed_at = null;

        this.fixture = TestBed.createComponent(TestingComponent);
        this.fixture.componentInstance.id = exp.id;
        this.fixture.detectChanges();
        this.timePipe = new HrMinSecPipe()

      }))

      it('should display actual remaining time', inject(
        [StatusService],
        (statusService: StatusService) => {
          let p = 0.5
          let r = 5

          spyOn(statusService, 'timePercentage').and.returnValue(p);
          spyOn(statusService, 'timeRemaining').and.returnValue(r);

          getExperimentCB(exp)
          this.fixture.detectChanges()
          statusService.$data.next(statusData)
          this.fixture.detectChanges()
          let el = this.fixture.debugElement.nativeElement

          expect(el.querySelector('.message-text > span').innerHTML.trim()).toBe('IN PROGRESS...')
          expect(el.querySelector('.message-text > strong').innerHTML.trim()).toBe(this.timePipe.transform(r) + ' Remaining')
          let bg = el.querySelector('.bg-placeholder')
          let s = {
            background: `linear-gradient(left,  #64b027 0%,#c6e35f ${p*100}%,#0c2c03 ${p*100}%,#0c2c03 100%)`
          }

          let style  = ngStyles(s)

          expect(bg.getAttribute('style')).toBe(style)

        }
      ))

      it('should fetch experiment when state changes to idle', inject(
        [StatusService, ExperimentService],
        (statusService: StatusService, expService: ExperimentService) => {

          getExperimentCB(exp)
          this.fixture.detectChanges()
          statusService.$data.next(statusData)
          this.fixture.detectChanges()

          statusData.experiment_controller.machine.state = 'idle'
          statusService.$data.next(statusData)
          this.fixture.detectChanges()
          expect(expService.getExperiment).toHaveBeenCalledTimes(2)
          exp.name = 'xxx'
          getExperimentCB(exp)
          this.fixture.detectChanges()
          expect(this.fixture.debugElement.nativeElement.querySelector('.exp-name').innerHTML.trim()).toBe('xxx')

        }
      ))

    })


    //describe('When experiment is in holding state', () => {

    //  beforeEach(async(() => {
    //    statusData.experiment_controller.experiment.id = exp.id
    //    exp.started_at = "2017-08-30T16:30:13.000Z";
    //    exp.completed_at = "2017-08-30T16:30:13.000Z";

    //    this.fixture = TestBed.createComponent(TestingComponent);
    //    this.fixture.componentInstance.id = exp.id;
    //    this.fixture.detectChanges();

    //  }))

    //  it('should display analyzing', inject(
    //    [StatusService],
    //    (statusService: StatusService) => {
    //      getExperimentCB(exp);
    //      this.fixture.detectChanges();
    //      statusService.$data.next(statusData);
    //      this.fixture.detectChanges();
    //      let el = this.fixture.debugElement.nativeElement;
    //      expect(el.querySelector('.status-indicator .message-text').innerHTML.trim()).toBe(`Analyzing... Holding Temperature of ${statusData.heat_block.temperature.toFixed(1)}`);
    //      let bgCon = el.querySelector('.bg-placeholder')
    //      let p = 1
    //      let s = {
    //        background: `linear-gradient(left,  #64b027 0%,#c6e35f ${p * 100}%,#0c2c03 ${p*100}%,#0c2c03 100%)`
    //      }
    //      let style = ngStyles(s)
    //      expect(bgCon.getAttribute('style')).toBe(style)
    //    }
    //  ))

    //  it('should display experiment complete, holding temperature', inject(
    //    [StatusService, ExperimentService],
    //    (statusService: StatusService, expService: ExperimentService) => {
    //      getExperimentCB(exp);
    //      this.fixture.detectChanges();
    //      statusService.$data.next(statusData);
    //      this.fixture.detectChanges();
    //      expUpdatesCB('experiment:completed');
    //      expect(expService.getExperiment).toHaveBeenCalledTimes(2)
    //      this.fixture.detectChanges();
    //      let el = this.fixture.debugElement.nativeElement;
    //      expect(el.querySelector('.status-indicator .message-text').innerHTML.trim()).toBe(`Experiment Complete, Holding Temperature of ${statusData.heat_block.temperature.toFixed(1)}`);
    //      let bgCon = el.querySelector('.bg-placeholder')
    //      let p = 1
    //      let s = {
    //        background: `linear-gradient(left,  #64b027 0%,#c6e35f ${p * 100}%,#0c2c03 ${p*100}%,#0c2c03 100%)`
    //      }
    //      let style = ngStyles(s)
    //      expect(bgCon.getAttribute('style')).toBe(style)

    //    }
    //  ))

    //})

    describe('When another experiment is running', () => {

      let exp: any;
      let statusData: any;

      beforeEach(async(() => {
        exp = JSON.parse(JSON.stringify(ExperimentMockInstance));
        statusData = JSON.parse(JSON.stringify(StatusDataMockInstance));
        exp.id = 1;
        statusData.experiment_controller.experiment.id = 1233423423;
      }))

      describe('When experiment has not been started', () => {

        beforeEach(() => {
          exp.started_at = null;
          exp.completed_at = null;
        })

        it('should display another experiment is running', inject(
          [ExperimentService, StatusService],
          (expService: ExperimentService, statusService: StatusService) => {
            this.fixture = TestBed.createComponent(TestingComponent);
            this.fixture.componentInstance.id = exp.id;
            this.fixture.detectChanges();
            getExperimentCB(exp);
            this.fixture.detectChanges();
            statusService.$data.next(statusData);
            this.fixture.detectChanges();
            let el = this.fixture.debugElement.nativeElement;
            expect(el.querySelector('.message-text').innerHTML.trim()).toBe('ANOTHER EXPERIMENT IS RUNNING');
            expect(el.querySelector('.message .button').innerHTML.trim()).toBe('VIEW NOW');
          }
        ));


      });

    });

  })

})

