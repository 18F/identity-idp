import React, { forwardRef } from 'react';

/**
 * @typedef PageHeadingProps
 *
 * @prop {import('react').ReactNode} children Child elements.
 */

/**
 * @param {PageHeadingProps & Record<string,any>} props Props object.
 */
function PageHeading({ children, className, ...props }, ref) {
  const classes = ['h3', 'my0', className].filter(Boolean).join(' ');

  return (
    // Disable reason: Intended as pass-through to heading HTML element.
    // eslint-disable-next-line react/jsx-props-no-spreading
    <h1 ref={ref} {...props} className={classes}>
      {children}
    </h1>
  );
}

export default forwardRef(PageHeading);
