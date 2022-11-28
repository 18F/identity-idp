interface RequestOptions extends RequestInit {
  /**
   * Either boolean or unstringified POJO to send with the request as JSON. Defaults to true.
   */
  json?: object | boolean;

  /**
   * Whether to include CSRF token in the request. Defaults to true.
   */
  csrf?: boolean;
}

const getCSRFToken = () =>
  document.querySelector<HTMLMetaElement>('meta[name="csrf-token"]')?.content;

export const request = async (url: string, options: Partial<RequestOptions> = {}) => {
  const { csrf = true, json = true, ...fetchOptions } = options;
  let { body, headers } = fetchOptions;
  headers = new Headers(headers);

  if (csrf) {
    const csrfToken = getCSRFToken();
    if (csrfToken) {
      headers.set('X-CSRF-Token', csrfToken);
    }
  }

  if (json) {
    headers.set('Content-Type', 'application/json');
    headers.set('Accept', 'application/json');

    if (typeof json !== 'boolean') {
      body = JSON.stringify(json);
    }
  }

  const response = await window.fetch(url, { ...fetchOptions, headers, body });
  return json ? response.json() : response.text();
};
