interface RequestOptions extends RequestInit {
  /**
   * Unstringified POJO to send with the request as JSON. Defaults to null.
   */
  json?: object;

  /**
   * Whether to include CSRF token in the request. Defaults to true.
   */
  csrf?: boolean;
}

const getCSRFToken = () =>
  document.querySelector<HTMLMetaElement>('meta[name="csrf-token"]')?.content;

export const request = async (url: string, options: Partial<RequestOptions> = {}) => {
  const { csrf = true, json = null, ...fetchOptions } = options;
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
    body = JSON.stringify(json);
  }

  const response = await fetch(url, { ...fetchOptions, headers, body });
  return json ? response.json() : response.text();
};
