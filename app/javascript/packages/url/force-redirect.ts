import removeUnloadProtection from './remove-unload-protection';

type Navigate = (url: string) => void;

const DEFAULT_NAVIGATE: Navigate = (url) => {
  window.location.href = url;
};

/**
 * Redirects the user to the given URL, bypassing any confirmation prompts that may exist to prevent
 * the user from leaving.
 *
 * @param url Destination URL.
 * @param navigate Navigation implementation, used for dependency injection.
 */
function forceRedirect(url: string, navigate: Navigate = DEFAULT_NAVIGATE) {
  removeUnloadProtection();
  navigate(url);
}

export default forceRedirect;
