window.LoginGov = window.LoginGov || {};

window.LoginGov.I18n = {
  currentLocale: function() { return this.__currentLocale || (this.__currentLocale = document.querySelector('html').lang); },
  strings: {},
  addStrings: function(data) {
    for (var key in data) {
      this.strings[key] = data[key];
    }
  },
  t: function(key) { return this.strings[key]; },
  key: function(key) { return key.replace(/[ -]/g, '_').replace(/\W/g, '').toLowerCase(); }
};
