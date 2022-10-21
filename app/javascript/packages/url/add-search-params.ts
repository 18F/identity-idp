/**
 * Given a URL or a string fragment of search parameters and an object of parameters, returns a
 * new URL or search parameters with the parameters added.
 *
 * @param url Original URL.
 * @param params Search parameters to add.
 *
 * @return Modified URL.
 */
function addSearchParams(url: string, params: Record<string, any>): string {
  const parsedURL = new URL(url, window.location.href);
  Object.entries(params).forEach(([key, value]) => parsedURL.searchParams.set(key, value));
  return parsedURL.toString();
}

export default addSearchParams;
