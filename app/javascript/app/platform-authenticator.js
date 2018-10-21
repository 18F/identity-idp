function platformAuthenticator() {
  const isEnabled = document.querySelector('[data-platform-authenticator-enabled]');
  if (isEnabled && window.PublicKeyCredential) {
    window.PublicKeyCredential.isUserVerifyingPlatformAuthenticatorAvailable()
      .then(function(userIntent) {
        const xhr = new XMLHttpRequest();
        xhr.open('POST', '/analytics', true);
        xhr.setRequestHeader('Content-type', 'application/x-www-form-urlencoded');
        xhr.send(`available=${userIntent}`);
      });
  }
}
document.addEventListener('DOMContentLoaded', platformAuthenticator);
