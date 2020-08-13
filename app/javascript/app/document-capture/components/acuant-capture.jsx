import React, { useContext, useState } from 'react';
import AcuantContext from '../context/acuant';
import AcuantCaptureCanvas from './acuant-capture-canvas';
import FullScreen from './full-screen';
import useI18n from '../hooks/use-i18n';

function AcuantCapture() {
  const { isReady, isError } = useContext(AcuantContext);
  const [isCapturing, setIsCapturing] = useState(false);
  const [capture, setCapture] = useState(null);
  const t = useI18n();

  if (isError) {
    return 'Error!';
  }

  if (!isReady) {
    return 'Loading…';
  }

  if (capture) {
    const { data, width, height } = capture.image;
    return <img alt="Captured result" src={data} width={width} height={height} />;
  }

  return (
    <>
      {isCapturing && (
        <FullScreen onRequestClose={() => setIsCapturing(false)}>
          <AcuantCaptureCanvas
            onImageCaptureSuccess={(nextCapture) => {
              setCapture(nextCapture);
              setIsCapturing(false);
            }}
            onImageCaptureFailure={() => setIsCapturing(false)}
          />
        </FullScreen>
      )}
      <button type="button" onClick={() => setIsCapturing(true)}>
        {t('doc_auth.buttons.take_picture')}
      </button>
    </>
  );
}

export default AcuantCapture;
