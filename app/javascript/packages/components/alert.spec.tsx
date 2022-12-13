import { createRef } from 'react';
import { render } from '@testing-library/react';
import Alert from './alert';
import type { AlertType } from './alert';

describe('Alert', () => {
  describe('role', () => {
    (
      [
        ['success', 'status'],
        ['warning', 'status'],
        ['error', 'alert'],
        ['info', 'status'],
        ['other', 'status'],
      ] as [AlertType, 'alert' | 'status'][]
    ).forEach(([type, role]) => {
      context(`with ${type} type`, () => {
        it(`should apply ${role} role`, () => {
          const { getByRole } = render(<Alert type={type} />);

          const alert = getByRole(role);

          expect(alert).to.be.ok();
        });
      });
    });
  });

  it('accepts additional class names', () => {
    const { getByRole } = render(
      <Alert type="warning" className="my-class">
        Uh oh!
      </Alert>,
    );

    const alert = getByRole('status');

    expect(alert.classList.contains('my-class')).to.be.true();
  });

  it('is optionally focusable', () => {
    const { getByRole } = render(<Alert isFocusable />);

    const alert = getByRole('status');
    alert.focus();

    expect(document.activeElement).to.equal(alert);
  });

  it('forwards ref', () => {
    const ref = createRef();
    const { container } = render(<Alert ref={ref} />);

    expect(ref.current).to.equal(container.firstChild);
  });

  it('renders children in the p element by default', () => {
    const { getByText } = render(<Alert>{'This is a test'}</Alert>);

    expect(getByText('This is a test').classList.contains('usa-alert__text'));
  });
  it('renders children directly in alert body when "body" prop is true', () => {
    const { getByText } = render(
      <Alert body={true}>
        <div className="test-class">{'This is a test'}</div>
      </Alert>,
    );
    const containingEl = getByText('This is a test');
    const parentEl = containingEl.parentElement as HTMLElement;

    expect(containingEl.classList.contains('test-class'));
    expect(parentEl.classList.contains('usa-alert__body'));
  });
});
