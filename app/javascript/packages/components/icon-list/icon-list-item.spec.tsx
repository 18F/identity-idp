import { render } from '@testing-library/react';
import IconListItem from './icon-list-item';

describe('IconListItem', () => {
  it('renders the component with expected class and children', () => {
    const { container } = render(
      <IconListItem icon="check_circle" title="Example title">
        <div>Example</div>
      </IconListItem>,
    );

    const wrapper = container.firstElementChild!;
    expect(wrapper.classList.contains('usa-icon-list__item')).to.be.true();

    const iconListIcon = wrapper.firstElementChild!;
    expect(iconListIcon.classList.contains('usa-icon-list__icon')).to.be.true();
    const icon = iconListIcon.firstElementChild!;
    expect(icon.classList.contains('usa-icon')).to.be.true();
    const iconListContent = iconListIcon.nextElementSibling!;
    expect(iconListContent.classList.contains('usa-icon-list__content')).to.be.true();
    const iconListTitle = iconListContent.firstElementChild!;
    expect(iconListTitle.classList.contains('usa-icon-list__title')).to.be.true();
    expect(iconListTitle.textContent).to.equal('Example title');
    const child = iconListTitle.nextElementSibling!;
    expect(child.textContent).to.equal('Example');
  });
});
