import { render } from '@testing-library/react';
import type { SinonSpy } from 'sinon';
import { useSandbox } from '@18f/identity-test-helpers';
import ScrollIntoView from './scroll-into-view';

describe('ScrollIntoView', () => {
  const sandbox = useSandbox();

  it('scrolls content into view', () => {
    sandbox.spy(Element.prototype, 'scrollIntoView');

    const { getByText } = render(<ScrollIntoView>Content</ScrollIntoView>);

    const text = getByText('Content');
    const call = (Element.prototype.scrollIntoView as SinonSpy).getCall(0);

    expect((call.thisValue as Element).contains(text)).to.be.true();
  });

  it('only scrolls into view on initial render', () => {
    sandbox.spy(Element.prototype, 'scrollIntoView');

    const { rerender } = render(<ScrollIntoView>Content1</ScrollIntoView>);
    rerender(<ScrollIntoView>Content2</ScrollIntoView>);

    expect(Element.prototype.scrollIntoView).to.have.been.calledOnce();
  });
});
