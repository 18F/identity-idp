import Button from './button';
import PageHeading from './page-heading';

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
  return (
    <>
      <PageHeading>Having trouble adding your state-issued ID?</PageHeading>
      {isAssessedAsGlare && <p>Glare</p>}
      {isAssessedAsBlurry && <p>Blurry</p>}
      <Button type="button" onClick={onTryAgain} isBig isWide className="display-block margin-y-5">
        Try again
      </Button>
    </>
  );
}

export default CaptureAdvice;
