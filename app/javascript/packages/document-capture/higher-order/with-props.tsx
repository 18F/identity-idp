function getDisplayName(ComponentWithBoundProps) {
  return ComponentWithBoundProps.displayName || ComponentWithBoundProps.name || 'Component';
}

// withProps returns a function that accepts a JSX component and binds
// some new props to that JSX component, then returns it.
function withProps(boundProps) {
  function bindProps(Component) {
    function ComponentWithBoundProps(props) {
      return <Component {...boundProps} {...props} />;
    }
    ComponentWithBoundProps.displayName = getDisplayName(Component);
    return ComponentWithBoundProps;
  }
  return (Component) => bindProps(Component);
}

export default withProps;
