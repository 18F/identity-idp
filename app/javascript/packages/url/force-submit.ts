import removeUnloadProtection from './remove-unload-protection';

type RequestMethod = 'POST' | 'PUT' | 'DELETE';

interface SubmitOptions {
  method?: RequestMethod;
}

/**
 * Submits a form to the given URL, bypassing any confirmation prompts that may exist to prevent the
 * user from leaving.
 *
 * @param url Destination URL.
 * @param options.method Request method.
 */
function forceSubmit(url: string, { method }: SubmitOptions = {}) {
  removeUnloadProtection();

  const form = document.createElement('form');
  form.method = 'POST';
  form.action = url;
  document.body.appendChild(form);

  const csrfToken = document.querySelector<HTMLMetaElement>('meta[name="csrf-token"]')?.content;
  if (csrfToken) {
    const csrfInput = document.createElement('input');
    csrfInput.type = 'hidden';
    csrfInput.name = 'authenticity_token';
    csrfInput.value = csrfToken;
    form.appendChild(csrfInput);
  }

  if (method) {
    const methodInput = document.createElement('input');
    methodInput.type = 'hidden';
    methodInput.name = '_method';
    methodInput.value = method;
    form.appendChild(methodInput);
  }

  form.submit();
}

export default forceSubmit;
