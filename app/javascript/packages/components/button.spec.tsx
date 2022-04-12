import { render } from '@testing-library/react';
import sinon from 'sinon';
import userEvent from '@testing-library/user-event';
import Button from './button';

describe('document-capture/components/button', () => {
  it('renders with default props', () => {
    const { getByText } = render(<Button>Click me</Button>);

    const button = getByText('Click me') as HTMLButtonElement;
    userEvent.click(button);

    expect(button.nodeName).to.equal('BUTTON');
    expect(button.type).to.equal('button');
    expect(button.classList.contains('usa-button')).to.be.true();
    expect(button.classList.contains('usa-button--big')).to.be.false();
    expect(button.classList.contains('usa-button--flexible-width')).to.be.false();
    expect(button.classList.contains('usa-button--wide')).to.be.false();
    expect(button.classList.contains('usa-button--outline')).to.be.false();
    expect(button.classList.contains('usa-button--unstyled')).to.be.false();
  });

  it('calls click callback with the event argument', () => {
    const onClick = sinon.spy();
    const { getByText } = render(
      <Button onClick={(event) => onClick(event.type)}>Click me</Button>,
    );

    const button = getByText('Click me');
    userEvent.click(button);

    expect(onClick.calledOnce).to.be.true();
    expect(onClick.getCall(0).args[0]).to.equal('click');
  });

  it('renders as big', () => {
    const { getByText } = render(<Button isBig>Click me</Button>);

    const button = getByText('Click me');

    expect(button.classList.contains('usa-button--big')).to.be.true();
  });

  it('renders as flexible width', () => {
    const { getByText } = render(<Button isFlexibleWidth>Click me</Button>);

    const button = getByText('Click me');

    expect(button.classList.contains('usa-button--flexible-width')).to.be.true();
  });

  it('renders as wide', () => {
    const { getByText } = render(<Button isWide>Click me</Button>);

    const button = getByText('Click me');

    expect(button.classList.contains('usa-button--wide')).to.be.true();
    expect(button.classList.contains('usa-button--outline')).to.be.false();
    expect(button.classList.contains('usa-button--unstyled')).to.be.false();
  });

  it('renders as outline', () => {
    const { getByText } = render(<Button isOutline>Click me</Button>);

    const button = getByText('Click me');

    expect(button.classList.contains('usa-button--wide')).to.be.false();
    expect(button.classList.contains('usa-button--outline')).to.be.true();
    expect(button.classList.contains('usa-button usa-button--wide')).to.be.false();
    expect(button.classList.contains('usa-button--unstyled')).to.be.false();
  });

  it('renders as unstyled', () => {
    const { getByText } = render(<Button isUnstyled>Click me</Button>);

    const button = getByText('Click me');

    expect(button.classList.contains('usa-button--wide')).to.be.false();
    expect(button.classList.contains('usa-button--outline')).to.be.false();
    expect(button.classList.contains('usa-button--unstyled')).to.be.true();
  });

  it('renders as disabled', () => {
    const onClick = sinon.spy();
    const { getByText } = render(
      <Button isDisabled onClick={onClick}>
        Click me
      </Button>,
    );

    const button = getByText('Click me') as HTMLButtonElement;
    userEvent.click(button);

    expect(onClick.calledOnce).to.be.false();
    expect(button.disabled).to.be.true();
  });

  it('renders with custom type', () => {
    const { getByText } = render(<Button type="submit">Click me</Button>);

    const button = getByText('Click me') as HTMLButtonElement;

    expect(button.type).to.equal('submit');
  });

  it('renders with custom class names', () => {
    const { getByText } = render(<Button className="my-button">Click me</Button>);

    const button = getByText('Click me');

    expect(button.classList.contains('my-button')).to.be.true();
  });
});
