import React from 'react';
import sinon from 'sinon';
import userEvent from '@testing-library/user-event';
import Button from '@18f/identity-document-capture/components/button';
import { render } from '../../../support/document-capture';

describe('document-capture/components/button', () => {
  it('renders with default props', () => {
    const { getByText } = render(<Button>Click me</Button>);

    const button = getByText('Click me');
    userEvent.click(button);

    expect(button.nodeName).to.equal('BUTTON');
    expect(button.type).to.equal('button');
    expect(button.classList.contains('btn')).to.be.true();
    expect(button.classList.contains('btn-primary')).to.be.false();
    expect(button.classList.contains('btn-secondary')).to.be.false();
    expect(button.classList.contains('btn-wide')).to.be.false();
    expect(button.classList.contains('btn-link')).to.be.false();
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

  it('renders as primary', () => {
    const { getByText } = render(<Button isPrimary>Click me</Button>);

    const button = getByText('Click me');

    expect(button.classList.contains('btn-primary')).to.be.true();
    expect(button.classList.contains('btn-secondary')).to.be.false();
    expect(button.classList.contains('btn-wide')).to.be.true();
    expect(button.classList.contains('btn-link')).to.be.false();
  });

  it('renders as secondary', () => {
    const { getByText } = render(<Button isSecondary>Click me</Button>);

    const button = getByText('Click me');

    expect(button.classList.contains('btn-primary')).to.be.false();
    expect(button.classList.contains('btn-secondary')).to.be.true();
    expect(button.classList.contains('btn-wide')).to.be.false();
    expect(button.classList.contains('btn-link')).to.be.false();
  });

  it('renders as unstyled', () => {
    const { getByText } = render(<Button isUnstyled>Click me</Button>);

    const button = getByText('Click me');

    expect(button.classList.contains('btn-primary')).to.be.false();
    expect(button.classList.contains('btn-secondary')).to.be.false();
    expect(button.classList.contains('btn-wide')).to.be.false();
    expect(button.classList.contains('btn-link')).to.be.true();
  });

  it('renders as disabled', () => {
    const onClick = sinon.spy();
    const { getByText } = render(
      <Button isDisabled onClick={onClick}>
        Click me
      </Button>,
    );

    const button = getByText('Click me');
    userEvent.click(button);

    expect(onClick.calledOnce).to.be.false();
    expect(button.disabled).to.be.true();
  });

  it('renders with custom type', () => {
    const { getByText } = render(<Button type="submit">Click me</Button>);

    const button = getByText('Click me');

    expect(button.type).to.equal('submit');
  });

  it('renders with custom class names', () => {
    const { getByText } = render(<Button className="my-button">Click me</Button>);

    const button = getByText('Click me');

    expect(button.classList.contains('my-button')).to.be.true();
  });
});
