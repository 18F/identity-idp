import { render } from '@testing-library/react';
import PageFooter from './page-footer';

describe('PageFooter', () => {
  it('renders its children content', () => {
    const { getByText } = render(<PageFooter>Content</PageFooter>);

    expect(getByText('Content')).to.exist();
  });
});
