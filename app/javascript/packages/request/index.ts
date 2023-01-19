type CSRFGetter = () => string | undefined;

interface RequestOptions extends RequestInit {
  /**
   * Either boolean or unstringified POJO to send with the request as JSON. Defaults to true.
   */
  json?: object | boolean;

  /**
   * Whether to include CSRF token in the request. Defaults to true.
   */
  csrf?: boolean | CSRFGetter;
}

const getCSRFToken = () =>
  document.querySelector<HTMLMetaElement>('meta[name="csrf-token"]')?.content;

export async function request<Response>(
  url: string,
  options: Partial<RequestOptions> = {},
): Promise<Response> {
  const { csrf = true, json = true, ...fetchOptions } = options;
  let { body, headers } = fetchOptions;
  headers = new Headers(headers);

  if (csrf) {
    const csrfToken = typeof csrf === 'boolean' ? getCSRFToken() : csrf();

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

  if (response.ok) {
    return json ? response.json() : response.text();
  }

  throw new Error(response.json());
}
