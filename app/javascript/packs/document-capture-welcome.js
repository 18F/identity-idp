const form = document.querySelector('form[action="/verify/doc_auth/welcome"]');

// TODO:
//  Change to: import { hasCamera } from '@18f/identity-device';
//  ...after:  https://github.com/18F/identity-idp/pull/4048
export async function hasCamera() {
  if (!('mediaDevices' in navigator)) {
    return false;
  }

  const devices = await navigator.mediaDevices.enumerateDevices();
  return devices.some((device) => device.kind === 'videoinput');
}

(async () => {
  if (form && (await hasCamera())) {
    const input = document.createElement('input');
    input.type = 'hidden';
    input.name = 'skip_upload';
    form.appendChild(input);
  }
})();
