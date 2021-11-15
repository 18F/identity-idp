import { render } from '@testing-library/react';
import withProps from '../../../../../app/javascript/packages/document-capture/higher-order/with-props';

describe('document-capture/higher-order/with-props', () => {
  describe('passes in property to component', () => {
    it('renders with front and back inputs', () => {
      const testProp = 'test2';
      const TestComponent = ({ test = 'test' }) => test;
      const WithPropComponent = withProps({ test: testProp })(TestComponent);

      const { getByText } = render(<WithPropComponent />);

      expect(getByText('test2')).to.be.ok();
    });
  });
});
