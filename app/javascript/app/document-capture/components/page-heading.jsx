import React from 'react';
import PropTypes from 'prop-types';

function PageHeading({ children }) {
  return <h1 className="h3 mt0">{children}</h1>;
}

PageHeading.propTypes = {
  children: PropTypes.node.isRequired,
};

export default PageHeading;
