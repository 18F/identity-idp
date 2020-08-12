import React from 'react';

/**
 * @typedef PageHeadingProps
 *
 * @prop {import('react').ReactNode} children Child elements.
 */

/**
 * @param {PageHeadingProps} props Props object.
 */
function PageHeading({ children }) {
  return <h1 className="h3 my0">{children}</h1>;
}

export default PageHeading;
