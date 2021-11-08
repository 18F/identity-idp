function withProps(boundProps) {
  return (Component) => (props) => <Component {...boundProps} {...props} />;
}

export default withProps;
