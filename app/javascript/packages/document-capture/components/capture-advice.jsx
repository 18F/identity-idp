import Button from './button';

/**
 * @typedef CaptureAdviceProps
 *
 * @prop {() => void} onTryAgain
 */

/**
 * @param {CaptureAdviceProps} props
 */
function CaptureAdvice({ onTryAgain }) {
  return <Button onClick={onTryAgain}>Try again</Button>;
}

export default CaptureAdvice;
