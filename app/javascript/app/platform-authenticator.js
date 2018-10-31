function postPlatformAuthenticator(userIntent) {
  const xhr = new XMLHttpRequest();
  xhr.open('POST', '/analytics', true);
  xhr.setRequestHeader('Content-type', 'application/x-www-form-urlencoded');
  xhr.send(`platform_authenticator[available]=${userIntent}`);
}
function platformAuthenticator() {
  if (document.querySelector('[data-platform-authenticator-enabled]')) {
    if (!window.PublicKeyCredential) {
      postPlatformAuthenticator(false);
      return;
    }
    window.PublicKeyCredential.isUserVerifyingPlatformAuthenticatorAvailable()
      .then(function(userIntent) {
        postPlatformAuthenticator(userIntent);
      });
  }
}
document.addEventListener('DOMContentLoaded', platformAuthenticator);
