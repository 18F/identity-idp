/**
 * Submits the given payload to the API route controller associated with the current path, resolving
 * to a promise containing the parsed response JSON object.
 *
 * @param payload Payload object.
 *
 * @return Parsed response JSON object.
 */
export async function post<Response = any>(payload: object): Promise<Response> {
  const { pathname, href } = window.location;
  const url = new URL(`/api${pathname}`, href).toString();
  const csrf = document.querySelector<HTMLMetaElement>('meta[name="csrf-token"]')?.content;
  const response = await window.fetch(url, {
    method: 'POST',
    headers: new Headers(
      [
        ['Content-Type', 'application/json'],
        ['X-CSRF-Token', csrf],
      ].filter(([, value]) => value) as [string, string][],
    ),
    body: JSON.stringify(payload),
  });
  return response.json();
}
