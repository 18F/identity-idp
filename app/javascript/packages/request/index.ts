type CSRFGetter = () => string | undefined;

export class ResponseError extends Error {
  status: number;
}

interface RequestOptions extends RequestInit {
  /**
   * Either boolean or unstringified POJO to send with the request as JSON. Defaults to true.
   */
  json?: object | boolean;

  /**
   * Whether to include the default CSRF token in the request, or use a custom implementation to
   * retrieve a CSRF token. Defaults to true.
   */
  csrf?: boolean | CSRFGetter;

  /**
   * Whether to automatically read the response as JSON or text. Defaults to true.
   */
  read?: boolean;
}

class CSRF {
  static get token(): string | null {
    return this.#tokenMetaElement?.content || null;
  }

  static set token(value: string | null) {
    if (!value) {
      return;
    }

    if (this.#tokenMetaElement) {
      this.#tokenMetaElement.content = value;
    }

    this.#paramInputElements.forEach((input) => {
      input.value = value;
    });
  }

  static get param(): string | undefined {
    return this.#paramMetaElement?.content;
  }

  static get #tokenMetaElement(): HTMLMetaElement | null {
    return document.querySelector('meta[name="csrf-token"]');
  }

  static get #paramMetaElement(): HTMLMetaElement | null {
    return document.querySelector('meta[name="csrf-param"]');
  }

  static get #paramInputElements(): NodeListOf<HTMLInputElement> {
    return document.querySelectorAll(`input[name="${this.param}"]`);
  }
}

/**
 * Returns true if the request associated with the given options would require a valid CSRF token,
 * or false otherwise.
 *
 * @see https://github.com/rails/rails/blob/v7.0.5/actionpack/lib/action_controller/metal/request_forgery_protection.rb#L335-L343
 *
 * @param options Request options
 *
 * @return Whether the request would require a CSRF token
 */
const isCSRFValidatedRequest = (options: RequestOptions) =>
  !!options.method && !['GET', 'HEAD'].includes(options.method.toUpperCase());

export async function request<Response = any>(
  url,
  options?: Partial<RequestOptions> & { read?: true },
): Promise<Response>;
export async function request(
  url,
  options?: Partial<RequestOptions> & { read?: false },
): Promise<Response>;
export async function request(url: string, options: Partial<RequestOptions> = {}) {
  const { csrf = true, json = true, read = true, ...fetchOptions } = options;
  let { body, headers } = fetchOptions;
  headers = new Headers(headers);

  if (csrf && isCSRFValidatedRequest(fetchOptions)) {
    const csrfToken = typeof csrf === 'boolean' ? CSRF.token : csrf();

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
  CSRF.token = response.headers.get('X-CSRF-Token');

  if (read) {
    if (!response.ok) {
      const error = new ResponseError();
      error.status = response.status;
      throw error;
    }

    return json ? response.json() : response.text();
  }

  return response;
}
