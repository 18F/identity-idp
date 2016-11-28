const root = window.LoginGov = (window.LoginGov || {});

root.autoLogout = function() {
  window.onbeforeunload = null;
  window.onunload = null;
  window.location.href = '/timeout';
};
