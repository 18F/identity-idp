import type { SinonSpy } from 'sinon';
import { useSandbox } from '@18f/identity-test-helpers';
import forceSubmit from './force-submit';

describe('forceSubmit', () => {
  const sandbox = useSandbox();

  beforeEach(() => {
    sandbox.stub(HTMLFormElement.prototype, 'submit');
  });

  it('removes unload protection and submits with default method', () => {
    sandbox.stub(window, 'onbeforeunload');
    sandbox.stub(window, 'onunload');

    forceSubmit('/example');

    expect(HTMLFormElement.prototype.submit).to.have.been.called();
    expect(window.onbeforeunload).to.be.null();
    expect(window.onunload).to.be.null();
    const call = (HTMLFormElement.prototype.submit as SinonSpy).getCall(0);
    const form: HTMLFormElement = call.thisValue;
    expect(form.method).to.equal('post');
    expect(form.action).to.equal(new URL('/example', window.location.href).toString());
    const csrfInput = form.querySelector<HTMLInputElement>('[name="authenticity_token"]');
    expect(csrfInput).to.be.null();
    const methodInput = form.querySelector<HTMLInputElement>('[name="_method"]');
    expect(methodInput).to.be.null();
  });

  context('with method', () => {
    it('submits with provided method', () => {
      forceSubmit('/example', { method: 'PUT' });

      const call = (HTMLFormElement.prototype.submit as SinonSpy).getCall(0);
      const form: HTMLFormElement = call.thisValue;
      expect(form.method).to.equal('post');
      const methodInput = form.querySelector<HTMLInputElement>('[name="_method"]');
      expect(methodInput!.value).to.equal('PUT');
      expect(methodInput!.type).to.equal('hidden');
    });
  });

  context('with csrf token present', () => {
    beforeEach(() => {
      const csrfMeta = document.createElement('meta');
      csrfMeta.name = 'csrf-token';
      csrfMeta.content = 'csrf-token-value';
      document.body.appendChild(csrfMeta);
    });

    it('submits with CSRF token', () => {
      forceSubmit('/example');

      const call = (HTMLFormElement.prototype.submit as SinonSpy).getCall(0);
      const form: HTMLFormElement = call.thisValue;
      const csrfInput = form.querySelector<HTMLInputElement>('[name="authenticity_token"]');
      expect(csrfInput!.value).to.equal('csrf-token-value');
      expect(csrfInput!.type).to.equal('hidden');
    });
  });
});
