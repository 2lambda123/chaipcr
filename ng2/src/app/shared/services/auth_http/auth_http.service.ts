import { Injectable } from '@angular/core';
import { Http, XHRBackend, RequestOptions, Request, RequestOptionsArgs, Response, Headers } from '@angular/http';
import { Observable } from 'rxjs/Observable';
import 'rxjs/add/operator/map';
import 'rxjs/add/operator/catch';

@Injectable()
export class AuthHttp extends Http {

  token_name = 'token';

  constructor(backend: XHRBackend, options: RequestOptions) {
    super(backend, options);
  }

  request(url: string | Request, options?: RequestOptionsArgs): Observable<Response> {
    let token = localStorage.getItem(this.token_name);
    if (typeof url === 'string') { // meaning we have to add the token to the options, not in url
      if (!options) {
        // let's make option object
        options = { headers: new Headers() };
      }
      url = this.appendTokenToUrl(url)
      options.headers.set('Authorization', `Bearer ${token}`);
    } else {
      // we have to add the token to the url object
      url.url = this.appendTokenToUrl(url.url)
      url.headers.set('Authorization', `Bearer ${token}`);
    }

    return super.request(url, options).catch(this.catchAuthError);
  }

  private appendTokenToUrl(url: string): string {
    let token = localStorage.getItem(this.token_name);
    if (url.indexOf('8000') >= 0) {
      let separator = url.indexOf('?') >= 0 ? '&' : '?'
      url = `${url}${separator}access_token=${token}`
    }
    return url
  }

  private catchAuthError(res: Response) {
    console.log(res);
    if (res.status === 401 || res.status === 403) {
      // if not authenticated
      console.log(res);
    }
    return Observable.throw(res);
  }
}