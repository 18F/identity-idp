import { t } from '@18f/identity-i18n';
import ReactDOM from 'react-dom';
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
  let rootContainer: HTMLDivElement;

  before(() => {
    rootContainer = document.createElement('div');
    document.body.appendChild(rootContainer);
  });

  afterEach(() => {
    ReactDOM.unmountComponentAtNode(rootContainer);
  });

  it('renders a back button', () => {
    act(() => {
      ReactDOM.render(<BackButton />, rootContainer);
    });
    const button = rootContainer.querySelector(':scope > button');
    expect(button).to.be.an.instanceof(HTMLElement);
    expect(rootContainer.innerHTML).to.equal(getButtonHtml());
  });

  it('processes the back button click', () => {
    const { wasClicked, onClick } = useOnClickTest();
    act(() => {
      ReactDOM.render(<BackButton onClick={onClick} />, rootContainer);
    });
    expect(wasClicked()).to.equal(false);
    const button = rootContainer.querySelector<HTMLElement>(':scope > button');
    button?.click();
    expect(wasClicked()).to.equal(true);
  });

  describe('with border', () => {
    it('renders a back button with a border', () => {
      act(() => {
        ReactDOM.render(<BackButton includeBorder />, rootContainer);
      });
      const button = rootContainer.querySelector<HTMLElement>(':scope > div > button');
      expect(button).to.be.an.instanceof(HTMLButtonElement);
      expect(rootContainer.innerHTML).to.equal(getBorderedButtonHtml());
    });

    it('processes the back button click', () => {
      const { wasClicked, onClick } = useOnClickTest();
      act(() => {
        ReactDOM.render(<BackButton includeBorder onClick={onClick} />, rootContainer);
      });
      expect(wasClicked()).to.equal(false);
      const button = rootContainer.querySelector<HTMLElement>(':scope > div > button');
      button?.click();
      expect(wasClicked()).to.equal(true);
    });
  });
});
