import { getAssetPath } from '@18f/identity-assets';

export default function AcuantSelfieInstructions() {
  return (
    <>
      <div className="margin-bottom-1 text-bold">How to take your photo</div>
      <div className="display-flex">
        <img
          src={getAssetPath('idv/selfie-capture-help.svg')}
          alt="A person with their face in a green oval."
        />
        <div className="margin-left-2">
          Line up your face with the green circle. Hold still and wait for the tool to capture a
          photo.
        </div>
      </div>
      <div className="display-flex">
        <img
          src={getAssetPath('idv/selfie-capture-accept-help.svg')}
          alt="A finger taps a checkmark under the face to confirm the photo."
        />
        <div className="margin-left-2">
          After your photo is automatically captured, tap the green checkmark to accept the photo.
        </div>
      </div>
    </>
  );
}
