import { TroubleshootingOptions } from '@18f/identity-components';
import { useContext } from 'react';
import { ServiceProviderContext } from '..';
import useAsset from '../hooks/use-asset';
import Button from './button';
import Warning from './warning';

/** @typedef {import('@18f/identity-components/troubleshooting-options').TroubleshootingOption} TroubleshootingOption */

/**
 * @typedef CaptureAdviceProps
 *
 * @prop {() => void} onTryAgain
 * @prop {boolean} isAssessedAsGlare
 * @prop {boolean} isAssessedAsBlurry
 */

/**
 * @param {CaptureAdviceProps} props
 */
function CaptureAdvice({ onTryAgain, isAssessedAsGlare, isAssessedAsBlurry }) {
  const { name: spName } = useContext(ServiceProviderContext);
  const { getAssetPath } = useAsset();

  return (
    <Warning
      heading="Having trouble adding your state-issued ID?"
      autoFocus
      actionText="Try again"
      actionOnClick={onTryAgain}
      troubleshootingHeading="Still having trouble?"
      troubleshootingOptions={
        /** @type {TroubleshootingOption[]} */ ([
          { url: '/', text: 'More tips for adding photos of your ID', isExternal: true },
          spName && {
            url: '/',
            text: (
              <>
                Get help at <strong>{spName}</strong>
              </>
            ),
            isExternal: true,
          },
        ].filter(Boolean))
      }
    >
      <p>
        {isAssessedAsGlare && 'The photo you added has glare. '}
        {isAssessedAsBlurry && 'The photo you added is too blurry. '}
        Here are some tips for taking a successful photo:
      </p>
      <ul className="add-list-reset margin-y-3">
        <li className="clearfix margin-bottom-3">
          <img
            width="82"
            height="82"
            src={getAssetPath('idv/capture-tips-flat-surface.svg')}
            alt=""
            className="float-left margin-right-2"
          />
          Take a photo on a flat surface with a dark background. Make sure the edges of your ID are
          clear.
        </li>
        <li className="clearfix margin-bottom-3">
          <img
            width="82"
            height="82"
            src={getAssetPath('idv/capture-tips-indirect-sunlight.svg')}
            alt=""
            className="float-left margin-right-2"
          />
          Make sure there is plenty of light. Indirect sunlight is best. Avoid glares, shadows and
          reflections.
        </li>
        <li className="clearfix">
          <img
            width="82"
            height="82"
            src={getAssetPath('idv/capture-tips-clean.svg')}
            alt=""
            className="float-left margin-right-2"
          />
          Make sure that the barcode is not damaged or dirty and all the information on your ID can
          be read.
        </li>
      </ul>
    </Warning>
  );
}

export default CaptureAdvice;
