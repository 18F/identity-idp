import { render } from '@testing-library/react';
import Icon from './icon';

describe('Icon', () => {
  it('renders given icon', () => {
    const { getByRole } = render(<Icon icon="add" />);

    const icon = getByRole('img', { hidden: true });

    expect(icon.classList.contains('usa-icon')).to.be.true();
    expect(icon.querySelector('use')!.getAttribute('href')).to.match(/#add$/);
  });

  context('with className prop', () => {
    it('renders with additional CSS class', () => {
      const { getByRole } = render(<Icon icon="add" className="my-custom-class" />);

      const icon = getByRole('img', { hidden: true });

      expect(Array.from(icon.classList.values())).to.include.members([
        'usa-icon',
        'my-custom-class',
      ]);
    });
  });
});
