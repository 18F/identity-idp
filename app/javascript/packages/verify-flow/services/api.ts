export interface ErrorResponse<Field extends string> {
  error: Record<Field, [string, ...string[]]>;
}

interface PostOptions {
  /**
   * Whether to send the request as a JSON request.
   */
  json: boolean;

  /**
   * Whether to include CSRF token in the request.
   */
  csrf: boolean;
}

/**
 * Submits the given payload to the API route controller associated with the current path, resolving
 * to a promise containing the parsed response JSON object.
 *
 * @param body Request body.
 *
 * @return Parsed response JSON object.
 */
export async function post<Response = any>(
  url: string,
  body: BodyInit | object,
  options: Partial<PostOptions> = {},
): Promise<Response> {
  const headers: HeadersInit = {};

  if (options.csrf) {
    const csrf = document.querySelector<HTMLMetaElement>('meta[name="csrf-token"]')?.content;
    if (csrf) {
      headers['X-CSRF-Token'] = csrf;
    }
  }

  if (options.json) {
    headers['Content-Type'] = 'application/json';
    body = JSON.stringify(body);
  }

  const response = await window.fetch(url, { method: 'POST', headers, body: body as BodyInit });

  return options.json ? response.json() : response.text();
}

export const isErrorResponse = <F extends string>(
  response: object | ErrorResponse<F>,
): response is ErrorResponse<F> => 'error' in response;
