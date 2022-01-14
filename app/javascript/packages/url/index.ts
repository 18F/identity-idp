/**
 * Given a URL or a string fragment of search parameters and an object of parameters, returns a
 * new URL or search parameters with the parameters added.
 *
 * @param urlOrParams Original URL or search parameters.
 * @param params Search parameters to add.
 *
 * @return Modified URL or search parameters.
 */
export function addSearchParams(urlOrParams: string, params: Record<string, any>): string {
  let parsedURLOrParams: URL | URLSearchParams;
  let searchParams: URLSearchParams;

  try {
    parsedURLOrParams = new URL(urlOrParams);
    searchParams = parsedURLOrParams.searchParams;
  } catch {
    parsedURLOrParams = new URLSearchParams(urlOrParams);
    searchParams = parsedURLOrParams;
  }

  Object.entries(params).forEach(([key, value]) => searchParams.set(key, value));

  const result = parsedURLOrParams.toString();
  return parsedURLOrParams instanceof URLSearchParams ? `?${result}` : result;
}
