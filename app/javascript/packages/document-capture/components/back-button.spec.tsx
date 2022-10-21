import { t } from '@18f/identity-i18n';
import { render } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import React from 'react';
import { act } from 'react-dom/test-utils';
import BackButton from './back-button';

const getButtonHtml = () =>
  `<button type="button" class="usa-button usa-button--unstyled">\u2039 ${t(
    'forms.buttons.back',
  )}</button>`;
const getBorderedButtonHtml = () =>
  `<div class="margin-top-5 padding-top-2 border-top border-primary-light"><button type="button" class="usa-button usa-button--unstyled">\u2039 ${t(
    'forms.buttons.back',
  )}</button></div>`;

const useOnClickTest = () => {
  let wasClicked = false;
  return {
    wasClicked: () => wasClicked,
    onClick: () => {
      wasClicked = true;
    },
  };
};

describe('BackButton', () => {
  let container: HTMLElement;
  let getByRole: ReturnType<typeof render>['getByRole'];

  const renderTestElement = (element: React.ReactElement) => {
    act(() => {
      const rendered = render(element);
      container = rendered.container;
      getByRole = rendered.getByRole;
    });
  };

  it('renders a back button', () => {
    renderTestElement(<BackButton />);
    const element = getByRole('button');
    expect(element).to.be.an.instanceof(HTMLElement);
    expect(container.innerHTML).to.equal(getButtonHtml());
  });

  it('processes the back button click', async () => {
    const { wasClicked, onClick } = useOnClickTest();
    renderTestElement(<BackButton onClick={onClick} />);
    expect(wasClicked()).to.equal(false);
    const button = getByRole('button');
    await userEvent.click(button);
    expect(wasClicked()).to.equal(true);
  });

  describe('with border', () => {
    it('renders a back button with a border', () => {
      renderTestElement(<BackButton includeBorder />);
      const button = getByRole('button');
      expect(button).to.be.an.instanceof(HTMLButtonElement);
      expect(container.innerHTML).to.equal(getBorderedButtonHtml());
    });

    it('processes the back button click', async () => {
      const { wasClicked, onClick } = useOnClickTest();
      renderTestElement(<BackButton includeBorder onClick={onClick} />);
      expect(wasClicked()).to.equal(false);
      const button = getByRole('button');
      await userEvent.click(button);
      expect(wasClicked()).to.equal(true);
    });
  });
});
