import { screen } from '@testing-library/dom';

describe('submit-with-spinner', () => {
  async function initialize({ withForm = true } = {}) {
    const parent = withForm
      ? document.body.appendChild(document.createElement('form'))
      : document.body;

    parent.innerHTML = `
      <button type='submit' class='btn btn-primary btn-wide sm-col sm-col-6'>
        Continue
      </button>
      <div class='sm-col sm-col-3'>
      <div class='spinner hidden' id='submit-spinner'>
        <img height="50" width="50" alt="Loading spinner" src="">
      </div>
      <div class='clearfix'></div>
    `;

    delete require.cache[require.resolve('../../../app/javascript/packs/submit-with-spinner')];
    await import('../../../app/javascript/packs/submit-with-spinner');
  }

  it('gracefully handles absence of form', async () => {
    await initialize({ withForm: false });
  });

  it('should show spinner on form submit', async () => {
    await initialize();

    // JSDOM doesn't support submitting a form natively.
    // See: https://github.com/jsdom/jsdom/issues/123
    const form = document.querySelector('form');
    const event = new window.Event('submit', { target: form });
    form.dispatchEvent(event);

    const spinner = screen.getByAltText('Loading spinner');

    expect(spinner.parentNode.classList.contains('hidden')).to.be.false();
  });
});
