// app/packs/upload-step.js
import { hasCamera } from '@18f/identity-device';

(async () => {
  if (await hasCamera()) {
    document.getElementById('upload-comp-liveness').classList.add('hidden');
    document.getElementById('upload-comp-liveness-off').classList.remove('hidden');
    document.getElementById('recommended-tag').classList.remove('hidden');
  }
})();
