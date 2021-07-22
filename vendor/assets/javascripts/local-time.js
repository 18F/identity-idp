// modifications marked with "Login.gov" original here: https://github.com/basecamp/local_time/blob/master/app/assets/javascripts/local-time.js

(function(){var t=this;(function(){(function(){var t=[].slice;

  // Login.gov   window.LocalTime={

    config:{},run:function(){return this.getController().processElements()},process:function(){var e,n,r,a;for(n=1<=arguments.length?t.call(arguments,0):[],r=0,a=n.length;r<a;r++)e=n[r],this.getController().processElement(e);return n.length},getController:function(){return null!=this.controller?this.controller:this.controller=new e.Controller}}}).call(this)}).call(t);

  // Login.gov
  var e=window.LocalTime;

  (function(){(function(){
    e.config.i18n={
      en: {
        date: {
          dayNames: ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"],
          abbrDayNames: ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"],
          monthNames: ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"],
          abbrMonthNames: ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"],
          yesterday: "yesterday",
          today: "today",
          tomorrow: "tomorrow",
          on: "on {date}",
          formats: {"default": "%b %e, %Y", thisYear: "%b %e"}
        },
        time: {
          am: "AM",
          pm: "PM",
          singular: "a {time}",
          singularAn: "an {time}",
          elapsed: "{time} ago",
          second: "second",
          seconds: "seconds",
          minute: "minute",
          minutes: "minutes",
          hour: "hour",
          hours: "hours",
          formats: {"default": "%l:%M %P"}
        }, datetime: {at: "{date} at {time}", formats: {"default": "%B %e, %Y at %l:%M %P %Z"}}
      },

  // Login.gov (only the translations we need have been modified)
      es: {
        date: {
          dayNames: ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"],
          abbrDayNames: ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"],
          monthNames: ["enero", "febrero", "marzo", "abril", "mayo", "junio", "julio", "agosto", "septiembre", "octubre", "noviembre", "diciembre"],
          abbrMonthNames: ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"],
          yesterday: "yesterday",
          today: "today",
          tomorrow: "tomorrow",
          on: "on {date}",
          formats: {"default": "%e %b %Y", thisYear: "%e %b"}
        },
        time: {
          am: "AM",
          pm: "PM",
          singular: "a {time}",
          singularAn: "an {time}",
          elapsed: "{time} ago",
          second: "second",
          seconds: "seconds",
          minute: "minute",
          minutes: "minutes",
          hour: "hour",
          hours: "hours",
          formats: {"default": "%l:%M %P"}
        }, datetime: {at: "{date} at {time}", formats: {"default": "%B %e, %Y at %l:%M %P %Z"}}
      },
      fr: {
        date: {
          dayNames: ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"],
          abbrDayNames: ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"],
          monthNames: ["janvier", "février", "mars", "avril", "mai", "juin", "juillet", "août", "septembre", "octobre", "novembre", "décembre"],
          abbrMonthNames: ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"],
          yesterday: "yesterday",
          today: "today",
          tomorrow: "tomorrow",
          on: "on {date}",
          formats: {"default": "%e %b %Y", thisYear: "%e %b"}
        },
        time: {
          am: "AM",
          pm: "PM",
          singular: "a {time}",
          singularAn: "an {time}",
          elapsed: "{time} ago",
          second: "second",
          seconds: "seconds",
          minute: "minute",
          minutes: "minutes",
          hour: "hour",
          hours: "hours",
          formats: {"default": "%l:%M %P"}
        }, datetime: {at: "{date} at {time}", formats: {"default": "%B %e, %Y at %l:%M %P %Z"}}
      },
    }
  }).call(this),function(){

  // Login.gov     var locale = location.pathname.split('/')[1];
    if (locale != 'fr' && locale != 'es') {
      locale = 'en';
    }
    e.config.locale = locale, e.config.defaultLocale = "en"

  }.call(this),function(){e.config.timerInterval=6e4}.call(this),function(){var t,n,r;r=!isNaN(Date.parse("2011-01-01T12:00:00-05:00")),e.parseDate=function(t){return t=t.toString(),r||(t=n(t)),new Date(Date.parse(t))},t=/^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})(Z|[-+]?[\d:]+)$/,n=function(e){var n,r,a,i,o,s,u,c,l;if(a=e.match(t))return a[0],c=a[1],o=a[2],n=a[3],r=a[4],i=a[5],u=a[6],l=a[7],"Z"!==l&&(s=l.replace(":","")),c+"/"+o+"/"+n+" "+r+":"+i+":"+u+" GMT"+[s]}}.call(this),function(){e.elementMatchesSelector=function(){var t,e,n,r,a,i;return t=document.documentElement,e=null!=(n=null!=(r=null!=(a=null!=(i=t.matches)?i:t.matchesSelector)?a:t.webkitMatchesSelector)?r:t.mozMatchesSelector)?n:t.msMatchesSelector,function(t,n){if((null!=t?t.nodeType:void 0)===Node.ELEMENT_NODE)return e.call(t,n)}}()}.call(this),function(){var t,n,r;t=e.config,r=t.i18n,e.getI18nValue=function(a,i){var o,s;return null==a&&(a=""),o=(null!=i?i:{locale:t.locale}).locale,s=n(r[o],a),null!=s?s:o!==t.defaultLocale?e.getI18nValue(a,{locale:t.defaultLocale}):void 0},e.translate=function(t,n,r){var a,i,o;null==n&&(n={}),o=e.getI18nValue(t,r);for(a in n)i=n[a],o=o.replace("{"+a+"}",i);return o},n=function(t,e){var n,r,a,i,o;for(o=t,i=e.split("."),n=0,a=i.length;n<a;n++){if(r=i[n],null==o[r])return null;o=o[r]}return o}}.call(this),function(){var t,n,r,a,i;t=e.getI18nValue,i=e.translate,e.strftime=a=function(e,o){var s,u,c,l,d,h,f;return u=e.getDay(),s=e.getDate(),d=e.getMonth(),f=e.getFullYear(),c=e.getHours(),l=e.getMinutes(),h=e.getSeconds(),o.replace(/%(-?)([%aAbBcdeHIlmMpPSwyYZ])/g,function(o,m,p){switch(p){case"%":return"%";case"a":return t("date.abbrDayNames")[u];case"A":return t("date.dayNames")[u];case"b":return t("date.abbrMonthNames")[d];case"B":return t("date.monthNames")[d];case"c":return e.toString();case"d":return n(s,m);case"e":return s;case"H":return n(c,m);case"I":return n(a(e,"%l"),m);case"l":return 0===c||12===c?12:(c+12)%12;case"m":return n(d+1,m);case"M":return n(l,m);case"p":return i("time."+(c>11?"pm":"am")).toUpperCase();case"P":return i("time."+(c>11?"pm":"am"));case"S":return n(h,m);case"w":return u;case"y":return n(f%100,m);case"Y":return f;case"Z":return r(e)}})},n=function(t,e){switch(e){case"-":return t;default:return("0"+t).slice(-2)}},r=function(t){var e,n,r,a,i;return i=t.toString(),(e=null!=(n=i.match(/\(([\w\s]+)\)$/))?n[1]:void 0)?/\s/.test(e)?e.match(/\b(\w)/g).join(""):e:(e=null!=(r=i.match(/(\w{3,4})\s\d{4}$/))?r[1]:void 0)?e:(e=null!=(a=i.match(/(UTC[\+\-]\d+)/))?a[1]:void 0)?e:""}}.call(this),function(){e.CalendarDate=function(){function t(t,e,n){this.date=new Date(Date.UTC(t,e-1)),this.date.setUTCDate(n),this.year=this.date.getUTCFullYear(),this.month=this.date.getUTCMonth()+1,this.day=this.date.getUTCDate(),this.value=this.date.getTime()}return t.fromDate=function(t){return new this(t.getFullYear(),t.getMonth()+1,t.getDate())},t.today=function(){return this.fromDate(new Date)},t.prototype.equals=function(t){return(null!=t?t.value:void 0)===this.value},t.prototype.is=function(t){return this.equals(t)},t.prototype.isToday=function(){return this.is(this.constructor.today())},t.prototype.occursOnSameYearAs=function(t){return this.year===(null!=t?t.year:void 0)},t.prototype.occursThisYear=function(){return this.occursOnSameYearAs(this.constructor.today())},t.prototype.daysSince=function(t){if(t)return(this.date-t.date)/864e5},t.prototype.daysPassed=function(){return this.constructor.today().daysSince(this)},t}()}.call(this),function(){var t,n,r;n=e.strftime,r=e.translate,t=e.getI18nValue,e.RelativeTime=function(){function a(t){this.date=t,this.calendarDate=e.CalendarDate.fromDate(this.date)}return a.prototype.toString=function(){var t,e;return(e=this.toTimeElapsedString())?r("time.elapsed",{time:e}):(t=this.toWeekdayString())?(e=this.toTimeString(),r("datetime.at",{date:t,time:e})):r("date.on",{date:this.toDateString()})},a.prototype.toTimeOrDateString=function(){return this.calendarDate.isToday()?this.toTimeString():this.toDateString()},a.prototype.toTimeElapsedString=function(){var t,e,n,a,i;return n=(new Date).getTime()-this.date.getTime(),a=Math.round(n/1e3),e=Math.round(a/60),t=Math.round(e/60),n<0?null:a<10?(i=r("time.second"),r("time.singular",{time:i})):a<45?a+" "+r("time.seconds"):a<90?(i=r("time.minute"),r("time.singular",{time:i})):e<45?e+" "+r("time.minutes"):e<90?(i=r("time.hour"),r("time.singularAn",{time:i})):t<24?t+" "+r("time.hours"):""},a.prototype.toWeekdayString=function(){switch(this.calendarDate.daysPassed()){case 0:return r("date.today");case 1:return r("date.yesterday");case-1:return r("date.tomorrow");case 2:case 3:case 4:case 5:case 6:return n(this.date,"%A");default:return""}},a.prototype.toDateString=function(){var e;return e=t(this.calendarDate.occursThisYear()?"date.formats.thisYear":"date.formats.default"),n(this.date,e)},a.prototype.toTimeString=function(){return n(this.date,t("time.formats.default"))},a}()}.call(this),function(){var t,n=function(t,e){return function(){return t.apply(e,arguments)}};t=e.elementMatchesSelector,e.PageObserver=function(){function e(t,e){this.selector=t,this.callback=e,this.processInsertion=n(this.processInsertion,this),this.processMutations=n(this.processMutations,this)}return e.prototype.start=function(){if(!this.started)return this.observeWithMutationObserver()||this.observeWithMutationEvent(),this.started=!0},e.prototype.observeWithMutationObserver=function(){var t;if("undefined"!=typeof MutationObserver&&null!==MutationObserver)return t=new MutationObserver(this.processMutations),t.observe(document.documentElement,{childList:!0,subtree:!0}),!0},e.prototype.observeWithMutationEvent=function(){return addEventListener("DOMNodeInserted",this.processInsertion,!1),!0},e.prototype.findSignificantElements=function(e){var n;return n=[],(null!=e?e.nodeType:void 0)===Node.ELEMENT_NODE&&(t(e,this.selector)&&n.push(e),n.push.apply(n,e.querySelectorAll(this.selector))),n},e.prototype.processMutations=function(t){var e,n,r,a,i,o,s,u;for(e=[],n=0,a=t.length;n<a;n++)switch(o=t[n],o.type){case"childList":for(u=o.addedNodes,r=0,i=u.length;r<i;r++)s=u[r],e.push.apply(e,this.findSignificantElements(s))}return this.notify(e)},e.prototype.processInsertion=function(t){var e;return e=this.findSignificantElements(t.target),this.notify(e)},e.prototype.notify=function(t){if(null!=t?t.length:void 0)return"function"==typeof this.callback?this.callback(t):void 0},e}()}.call(this),function(){var t,n,r,a,i=function(t,e){return function(){return t.apply(e,arguments)}};r=e.parseDate,a=e.strftime,n=e.getI18nValue,t=e.config,e.Controller=function(){function o(){this.processElements=i(this.processElements,this),this.pageObserver=new e.PageObserver(s,this.processElements)}var s,u,c;return s="time[data-local]:not([data-localized])",o.prototype.start=function(){if(!this.started)return this.processElements(),this.startTimer(),this.pageObserver.start(),this.started=!0},o.prototype.startTimer=function(){var e;if(e=t.timerInterval)return null!=this.timer?this.timer:this.timer=setInterval(this.processElements,e)},o.prototype.processElements=function(t){var e,n,r;for(null==t&&(t=document.querySelectorAll(s)),n=0,r=t.length;n<r;n++)e=t[n],this.processElement(e);return t.length},o.prototype.processElement=function(t){var e,i,o,s,l,d;if(i=t.getAttribute("datetime"),o=t.getAttribute("data-format"),s=t.getAttribute("data-local"),l=r(i),!isNaN(l))return t.hasAttribute("title")||(d=a(l,n("datetime.formats.default")),t.setAttribute("title",d)),t.textContent=e=function(){switch(s){case"time":return u(t),a(l,o);case"date":return u(t),c(l).toDateString();case"time-ago":return c(l).toString();case"time-or-date":return c(l).toTimeOrDateString();case"weekday":return c(l).toWeekdayString();case"weekday-or-date":return c(l).toWeekdayString()||c(l).toDateString()}}(),t.hasAttribute("aria-label")?void 0:t.setAttribute("aria-label",e)},u=function(t){return t.setAttribute("data-localized","")},c=function(t){return new e.RelativeTime(t)},o}()}.call(this),function(){var t,n,r,a;a=!1,t=function(){return document.attachEvent?"complete"===document.readyState:"loading"!==document.readyState},n=function(t){var e;return null!=(e="function"==typeof requestAnimationFrame?requestAnimationFrame(t):void 0)?e:setTimeout(t,17)},r=function(){var t;return t=e.getController(),t.start()},e.start=function(){if(!a)return a=!0,"undefined"!=typeof MutationObserver&&null!==MutationObserver||t()?r():n(r)},window.LocalTime===e&&e.start()}.call(this)}).call(this),"object"==typeof module&&module.exports?module.exports=e:"function"==typeof define&&define.amd&&define(e)}).call(this);
