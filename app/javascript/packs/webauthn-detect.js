const WebAuthn = require('../app/webauthn');
const highlightRadioBtn = require('../app/radio-btn').highlightRadioBtn;

function detectWebauthn() {
  const webauthnOption = document.querySelector('label[for=two_factor_options_form_selection_webauthn]');
  const parentNode = webauthnOption.parentNode;

  // might have to be window.PublicKeyCredential?? check js/app/platform-authenticator.js
  PublicKeyCredential.isUserVerifyingPlatformAuthenticatorAvailable().then(function (platformAvailable) {
    // FIXME remove exclaimation
    if (!platformAvailable) {

      const currentPlatform = navigator.platform;

      // create a new option if platform is detected
      const detectedOption = webauthnOption.cloneNode(true);

      // add it to the top of the options list
      parentNode.insertBefore(detectedOption, webauthnOption);

      // calling this again bc the detected one wasn't recognized the first time
      highlightRadioBtn();

      // change id name
      detectedOption.setAttribute('for', 'two_factor_options_form_selection_detected');
      detectedOption.querySelector('input[type=radio]').setAttribute('id', 'two_factor_options_form_selection_detected');

      // change label value
      const optionLabel = detectedOption.getElementsByClassName('blue bold fs-20p')[0];
      optionLabel.innerHTML = 'Use your ' + currentPlatform;

      // change info value
      const optionInfo = detectedOption.getElementsByClassName('regular gray-dark fs-10p mt0 mb-tiny')[0];
      optionInfo.innerHTML = 'Use your ' + currentPlatform + ' to secure your account';

      // change tooltip value
      const optionTooltip = detectedOption.getElementsByClassName('hint--right hint--no-animate')[0];
      console.log(optionTooltip);
      optionTooltip.setAttribute('aria-label', 'haha shoot');

      // bye bye webauthn coloring bc detected option is now at the top!
      webauthnOption.classList.remove('bg-lightest-blue');

    }
  });

}
document.addEventListener('DOMContentLoaded', detectWebauthn);
