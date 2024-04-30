import { render } from '@testing-library/react';
import withProps from '@18f/identity-document-capture/higher-order/with-props';

describe('document-capture/higher-order/with-props', () => {
  describe('passes in property to component', () => {
    it('renders withProp updated component correctly', () => {
      const testProp = 'test2';
      const TestComponent = ({ test = 'test' }) => test;
      const WithPropComponent = withProps({ test: testProp })(TestComponent);

      const { getByText } = render(<WithPropComponent />);

      expect(getByText('test2')).to.be.ok();
    });
    it('has a WithProps(Component) displayName', () => {
      const TestComponent = ({ test = 'test' }) => test;
      const displayName = `WithProps(TestComponentName)`;
      TestComponent.displayName = displayName;
      const WithPropComponent = withProps({ test: 'testProp' })(TestComponent);

      expect(WithPropComponent.displayName).to.equal(displayName);
    });
  });
});
