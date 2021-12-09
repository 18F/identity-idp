/**
 * Given a URL or a string fragment of search parameters and an object of parameters, returns a
 * new URL or search parameters with the parameters added.
 *
 * @param {string} urlOrParams Original URL or search parameters.
 * @param {Record<string, *>} params Search parameters to add.
 *
 * @return {string} Modified URL or search parameters.
 */
export function addSearchParams(urlOrParams, params) {
  /** @type {URL|URLSearchParams} */
  let parsedURLOrParams;

  /** @type {URLSearchParams} */
  let searchParams;

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
