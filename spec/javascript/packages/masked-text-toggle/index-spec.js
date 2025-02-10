import MaskedTextToggle from '@18f/identity-masked-text-toggle';
import { screen } from '@testing-library/dom';
import userEvent from '@testing-library/user-event';

describe('MaskedTextToggle', () => {
  beforeEach(() => {
    document.body.innerHTML = `
      <span id="masked-text-1fd0eb71134c">
        <span class="masked-text__text" data-masked="true">
          <span class="usa-sr-only">secure text, starting with 1 and ending with 4</span>
          <span aria-hidden="true">1**-**-***4</span>
        </span>
        <span class="masked-text__text display-none" data-masked="false">
          123-12-1234
        </span>
      </span>
      <div class="margin-top-2">
        <input
          type="checkbox"
          id="masked-text-1fd0eb71134c-checkbox"
          aria-controls="masked-text-1fd0eb71134c"
          class="masked-text__toggle usa-checkbox__input usa-checkbox__input--bordered"
          aria-label="Show Social Security Number"
        >
        <label
          for="masked-text-1fd0eb71134c-checkbox"
          class="usa-checkbox__label"
        >
          Show Social Security Number
        </label>
      </div>
    `;
  });

  const getToggle = () => screen.getByRole('checkbox');
  const initialize = () => new MaskedTextToggle(getToggle()).bind();

  it('sets initial visibility', async () => {
    await userEvent.click(getToggle());
    initialize();

    screen.getByText('123-12-1234', { ignore: '.display-none' });
  });

  it('toggles masked texts', async () => {
    initialize();

    expect(screen.getByText('123-12-1234').closest('.display-none')).to.exist();
    expect(screen.getByText('1**-**-***4').closest('.display-none')).to.not.exist();

    await userEvent.click(getToggle());

    expect(screen.getByText('123-12-1234').closest('.display-none')).to.not.exist();
    expect(screen.getByText('1**-**-***4').closest('.display-none')).to.exist();
  });
});
