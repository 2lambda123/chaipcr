import {
  Component,
  Input,
  Output,
  EventEmitter,
  OnChanges,
  SimpleChanges,
  OnInit,
  ElementRef,
  HostListener
} from '@angular/core';

import { WellButtonI } from '../../models/well-button.model';
import { ChartConfigService } from '../../../services/chart-config/base-chart-config.service';
import { WindowRef } from '../../../services/windowref/windowref.service';

@Component({
  selector: '[chai-well-buttons]',
  templateUrl: './well-buttons.component.html',
  styleUrls: ['./well-buttons.component.scss']
})
export class WellButtonsComponent implements OnChanges, OnInit {

  readonly ROW_HEADER_WIDTH = 30;
  readonly BORDER_WIDTH = 5;
  readonly NUM_WELLS = 16;
  readonly MARGIN = 15;

  public _wells: any;
  public rows: Array<any>;
  public cols: Array<any>;
  public isCmdKeyHeld = false;
  public isDragging = false;
  public dragStartingPoint: {type: string, index:number};

  @Input() colorby: string;
  @Output() onSelectWells = new EventEmitter<Array<WellButtonI>>();
  @Input()
  set wells(w) {
    if(!w) {
      this._wells = {};
      this.initWells();
    }
  }
  @HostListener('document:keypress', ['$event'])
  onKeyDown(e) {
    console.log(e)
  }

  constructor(
    private config: ChartConfigService,
    private el: ElementRef,
    private wref: WindowRef
  ) {
    this._wells = {};
    this.cols = [];
    this.rows = [];
    for (let i = 0; i < 8; i ++) {
      this.cols.push({
        index: i,
        selected: false
      });
    }
    for (let i = 0; i < 2; i ++) {
      this.rows.push({
        index: i,
        selected: false
      });
    }
  }

  isCtrlKeyHeld(e) {
    return e.ctrlKey || this.isCmdKeyHeld
  }

  getWidth():number {
    return this.el.nativeElement.parentElement.offsetWidth
  }

  getCellWidth() {
    return (this.getWidth() - this.ROW_HEADER_WIDTH) / this.cols.length
  }

  getWellIndex(row, col) {
    return (row.index * this.cols.length) + col.index;
  }

  getWell(row, col) {
    let i = this.getWellIndex(row, col)
    let well = this._wells[`well_${i}`]
    return well
  }

  getWellContainerStyle(row, col, well, i) {
    let style: any = {};
    style.opacity = 0.5;
    style.width = `${this.getCellWidth() - this.MARGIN * 2}px`;
    style.height = `${this.getCellWidth() - this.MARGIN * 2}px`;
    style.margin = `${this.MARGIN}px`;
    style.borderWidth = `${this.BORDER_WIDTH}px`;
    style.lineHeight = `${this.getCellWidth() - this.MARGIN * 2}px`;
    if (well.active) {
    }
    if (well.selected) {
      style.opacity = 1;
    }
    style.borderColor = well.color;
    return style;
  }

  ngOnInit() {
    this.initWells();
  }

  dragStart(e, t: string, i: number) {
    this.isDragging = true;
    this.dragStartingPoint = {
      type: t,
      index: i
    }
  }

  dragged(e, type, index) {
    if (!this.isDragging) return;
    if (type === this.dragStartingPoint.type && index === this.dragStartingPoint.index) return;
    switch(this.dragStartingPoint.type) {
      case 'column': {
        if (type === 'well')
          index = index >= this.cols.length ? index - this.cols.length : index
        let max = Math.max.apply(Math, [index, this.dragStartingPoint.index])
        let min = max === index ? this.dragStartingPoint.index : index
        this.cols.forEach((col) => {
          col.selected = col.index >= min && col.index <= max
          this.rows.forEach((row) => {
            let well = this._wells[`well_${row.index * this.cols.length + col.index}`]
            if(!(this.isCtrlKeyHeld(e) && well.selected))
              well.selected = col.selected
          })
        })
        break
      } case 'row': {
        if(type === 'well')
          index = index >= 8? 1 : 0;
        let max = Math.max.apply(Math, [index, this.dragStartingPoint.index])
        let min = max === index? this.dragStartingPoint.index : index
        this.rows.forEach((row) => {
          row.selected = row.index >= min && row.index <= max
          this.cols.forEach((col) => {
            let well = this._wells[`well_${row.index * this.cols.length + col.index}`]
            if(!(this.isCtrlKeyHeld(e) && well.selected))
              well.selected = row.selected
          })
        })
        break;
      } case 'well': {
        if(type === 'well') {
          let row1 = Math.floor(this.dragStartingPoint.index / this.cols.length)
          let col1 = this.dragStartingPoint.index - row1 * this.cols.length
          let row2 = Math.floor(index / this.cols.length)
          let col2 = index - row2 * this.cols.length
          let max_row = Math.max.apply(Math, [row1, row2])
          let min_row = max_row === row1? row2 : row1
          let max_col = Math.max.apply(Math, [col1, col2])
          let min_col = max_col === col1? col2: col1
          this.rows.forEach((row) => {
            this.cols.forEach((col) => {
              let selected = (row.index >= min_row && row.index <= max_row) && (col.index >= min_col && col.index <= max_col)
              let well = this._wells[`well_${row.index * this.cols.length + col.index}`]
              if(!(this.isCtrlKeyHeld(e) && well.selected))
                well.selected = selected
            })
          })
        }
      }
    }
  }

  dragStop(e, t, i) {
    this.isDragging = false;
    this.cols.forEach((col) => {
      col.selected = false
    })
    this.rows.forEach((row) => {
      row.selected = false
    })
    if(t === 'well' && i === this.dragStartingPoint.index) {
      if (!this.isCtrlKeyHeld(e)) {
        this.rows.forEach((r) => {
          this.cols.forEach((c) => {
            this._wells[`well_${r.index * this.cols.length + c.index}`].selected = false
          })
        })
      }
      let well = this._wells[`well_${i}`]
      well.selected = this.isCtrlKeyHeld(e) ? !well.selected : true
    }
    this.onSelectWells.emit(this._wells);
  }

  getWellName(row, col) {
    let rows = ['A', 'B']
    return `${rows[row.index]}${col.index + 1}`;
  }
  //getWellStyle(row, col, well, index) {
  //  if(well.active)
  //    return {}

  //  let well_left_index = (col.index + 1) % this.cols.length === 1 ? null : index - 1
  //  let well_right_index = (col.index + 1) % this.cols.length === 0 ? null : index + 1
  //  let well_top_index = (row.index + 1) % this.rows.length === 1 ? null : index - this.cols.length
  //  let well_bottom_index = (row.index + 1) % this.rows.length === 0 ? null : index + this.cols.length

  //  let well_left = this._wells[`well_${well_left_index}`]
  //  let well_right = this._wells[`well_${well_right_index}`]
  //  let well_top = this._wells[`well_${well_top_index}`]
  //  let well_bottom = this._wells[`well_${well_bottom_index}`]

  //  let style: any = {}
  //  let border = `2px solid #000`

  //  if (well.selected) {
  //    if(!(well_left? well_left.selected : false))
  //      style[`border-left`] = border
  //    if(!(well_right? well_right.selected : false))
  //      style[`border-right`] = border
  //    if(!(well_top? well_top.selected : false))
  //      style[`border-top`] = border
  //    if(!(well_bottom? well_bottom.selected : false))
  //      style[`border-bottom`] = border
  //  }
  //  return style;
  //}

  private initWells() {
    for (let i = 0; i < this.NUM_WELLS; i ++) {
      this._wells[`well_${i}`] = {
        active: false,
        selected: true,
        color: this.colorby === 'well' ? this.config.getColors()[i] : '#75278E',
        cts: [1, 2]
      }
    }
    this.onSelectWells.emit(this._wells);
  }

  ngOnChanges(changes: SimpleChanges):void {
    if (changes.colorby.previousValue !== changes.colorby.currentValue) {
      for (let i = 0; i < this.NUM_WELLS; i ++) {
        this._wells[`well_${i}`].color = this.colorby === 'well' ? this.config.getColors()[i] : '#75278E'
      }
    }
  }

}
