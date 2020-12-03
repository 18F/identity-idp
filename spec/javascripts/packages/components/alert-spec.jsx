import { Alert } from '@18f/identity-components';
import { render } from '../../support/document-capture';

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
});
