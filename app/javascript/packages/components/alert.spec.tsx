import { createRef } from 'react';
import { render } from '@testing-library/react';
import Alert from './alert';

describe('identity-components/alert', () => {
  it('should apply alert role', () => {
    const { getByRole } = render(<Alert type="warning">Uh oh!</Alert>);

    const alert = getByRole('alert');

    expect(alert).to.be.ok();
  });

  it('accepts additional class names', () => {
    const { getByRole } = render(
      <Alert type="warning" className="my-class">
        Uh oh!
      </Alert>,
    );

    const alert = getByRole('alert');

    expect(alert.classList.contains('my-class')).to.be.true();
  });

  it('is optionally focusable', () => {
    const { getByRole } = render(<Alert isFocusable />);

    const alert = getByRole('alert');
    alert.focus();

    expect(document.activeElement).to.equal(alert);
  });

  it('forwards ref', () => {
    const ref = createRef();
    const { container } = render(<Alert ref={ref} />);

    expect(ref.current).to.equal(container.firstChild);
  });
});
