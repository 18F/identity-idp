import sinon from 'sinon';
import { getByRole, fireEvent } from '@testing-library/dom';
import './form-link-element';

describe('FormLinkElement', () => {
  function createElement() {
    document.body.innerHTML = `
      <lg-form-link>
        <a href="https://example.com">Submit</a>
        <form method="post" action="https://example.com" class="display-none"></form>
      </lg-form-link>
    `;

    return document.body.querySelector('lg-form-link')!;
  }

  it('submits form on link click', () => {
    const element = createElement();
    const link = getByRole(element, 'link');

    const onSubmit = sinon.stub();
    element.form.submit = onSubmit;
    const didPreventDefault = !fireEvent.click(link);

    expect(onSubmit).to.have.been.called();
    expect(didPreventDefault).to.be.true();
  });
});
