// app/packs/upload-step.js
import { hasCamera } from '@18f/identity-device';

(async () => {
  if (await hasCamera()) {
    document.getElementById('upload-comp-liveness').classList.add('display-none');
    document.getElementById('upload-comp-liveness-off').classList.remove('display-none');
    document.getElementById('recommended-tag').classList.remove('display-none');
  }
})();
