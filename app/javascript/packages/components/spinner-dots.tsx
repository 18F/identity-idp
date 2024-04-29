interface SpinnerDotsProps {
  // Whether to absolutely-position the element at its container's center. Defaults to false.
  isCentered: boolean;
  // Optional class name.
  className?: string;
}

/**
 * @param {SpinnerDotsProps} props
 */
function SpinnerDots({ isCentered, className }: SpinnerDotsProps) {
  const classes = ['spinner-dots', isCentered && 'spinner-dots--centered', className]
    .filter(Boolean)
    .join(' ');

  return (
    <span className={classes} aria-hidden>
      <span className="spinner-dots__dot" />
      <span className="spinner-dots__dot" />
      <span className="spinner-dots__dot" />
    </span>
  );
}

export default SpinnerDots;
