import sinon from 'sinon';
import { act, cleanup } from '@testing-library/react';

export function useAcuant() {
  afterEach(() => {
    // While React Testing Library will perform this automatically, it must to occur prior to
    // resetting the global variables, since otherwise the component's effect unsubscribe will
    // attempt to reference globals that no longer exist.
    cleanup();
    delete window.AcuantJavascriptWebSdk;
    delete window.AcuantCamera;
    delete window.AcuantCameraUI;
  });

  return {
    initialize({ isSuccess = true, isCameraSupported = true } = {}) {
      window.AcuantJavascriptWebSdk = {
        initialize: (_credentials, _endpoint, { onSuccess, onFail }) =>
          isSuccess ? onSuccess() : onFail(),
      };
      window.AcuantCamera = { isCameraSupported };
      window.AcuantCameraUI = { start: sinon.stub(), end: sinon.stub() };
      act(window.onAcuantSdkLoaded);
    },
  };
}
