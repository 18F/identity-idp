import MaskedTextToggle from '@18f/identity-masked-text-toggle';
import { screen } from '@testing-library/dom';
import userEvent from '@testing-library/user-event';

describe('MaskedTextToggle', () => {
  beforeEach(() => {
    document.body.innerHTML = `
      <span id="masked-text-1fd0eb71134c">
        <span class="ads-masked-text__text" data-masked="true">
          <span class="ads-sr-only">secure text, starting with 1 and ending with 4</span>
          <span aria-hidden="true">1**-**-***4</span>
        </span>
        <span class="ads-masked-text__text" data-masked="false" hidden>
          123-12-1234
        </span>
      </span>
      <div class="ads-masked-text__toggle-row">
        <input
          type="checkbox"
          id="masked-text-1fd0eb71134c-checkbox"
          aria-controls="masked-text-1fd0eb71134c"
          class="ads-masked-text__toggle ads-sr-only"
          aria-label="Show Social Security Number"
        >
        <label
          for="masked-text-1fd0eb71134c-checkbox"
          class="ads-checkbox__label"
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

    expect(screen.getByText('123-12-1234').closest('[hidden]')).to.not.exist();
  });

  it('toggles masked texts', async () => {
    initialize();

    expect(screen.getByText('123-12-1234').closest('[hidden]')).to.exist();
    expect(screen.getByText('1**-**-***4').closest('[hidden]')).to.not.exist();

    await userEvent.click(getToggle());

    expect(screen.getByText('123-12-1234').closest('[hidden]')).to.not.exist();
    expect(screen.getByText('1**-**-***4').closest('[hidden]')).to.exist();
  });
});
