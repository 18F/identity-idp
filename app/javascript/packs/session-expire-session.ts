const expireConfig = document.getElementById('js-expire-session');

if (expireConfig && expireConfig.dataset.sessionTimeoutIn) {
  const sessionTimeoutIn = parseInt(expireConfig.dataset.sessionTimeoutIn, 10) * 1000;
  const timeoutRefreshPath = expireConfig.dataset.timeoutRefreshPath || '';

  setTimeout(() => {
    document.location.href = timeoutRefreshPath;
  }, sessionTimeoutIn);
}
