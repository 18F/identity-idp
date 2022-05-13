/**
 * Given a URL or a string fragment of search parameters and an object of parameters, returns a
 * new URL or search parameters with the parameters added.
 *
 * @param url Original URL, path, or search parameters.
 * @param params Search parameters to add.
 *
 * @return Modified URL or search parameters.
 */
export function addSearchParams(url: string, params: Record<string, any>): string {
  const [prefix, searchAndFragment = ''] = url.split('?') as [string] | [string, string];
  const [search, fragment] = searchAndFragment.split('#') as [string] | [string, string];
  const searchParams = new URLSearchParams(search);
  Object.entries(params).forEach(([key, value]) => searchParams.set(key, value));
  return [prefix, [searchParams.toString(), fragment].filter(Boolean).join('#')].join('?');
}
