export const resolveFooterNavigationUrl = (value: string, baseUrl: string | URL) => {
  if (!value) {
    return undefined;
  }

  try {
    const url = new URL(value, baseUrl);
    return ['http:', 'https:'].includes(url.protocol) ? url.href : undefined;
  } catch {
    return undefined;
  }
};

type FooterLocation = Pick<Location, 'assign' | 'href'>;

export const navigateFooterSelect = (
  select: HTMLSelectElement,
  location: FooterLocation = window.location,
) => {
  const destination = resolveFooterNavigationUrl(select.value, location.href);
  if (!destination) {
    return false;
  }

  if (select.dataset.adsFooterNavigationReset === 'true') {
    select.selectedIndex = 0;
  }

  location.assign(destination);
  return true;
};

class AdsPageFooterElement extends HTMLElement {
  #connectionController?: AbortController;

  connectedCallback() {
    this.#connectionController?.abort();
    this.#connectionController = new window.AbortController();
    this.addEventListener('change', this.handleChange, {
      signal: this.#connectionController.signal,
    });
  }

  disconnectedCallback() {
    this.#connectionController?.abort();
    this.#connectionController = undefined;
  }

  private handleChange = (event: Event) => {
    const select = event.target;
    if (!(select instanceof HTMLSelectElement) || !select.matches('[data-ads-footer-navigation]')) {
      return;
    }

    navigateFooterSelect(select);
  };
}

declare global {
  interface HTMLElementTagNameMap {
    'lg-ads-page-footer': AdsPageFooterElement;
  }
}

if (!customElements.get('lg-ads-page-footer')) {
  customElements.define('lg-ads-page-footer', AdsPageFooterElement);
}

export default AdsPageFooterElement;
