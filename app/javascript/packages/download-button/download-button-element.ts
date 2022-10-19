declare global {
  interface Navigator {
    msSaveBlob?: (blob: Blob, filename: string) => void;
  }
}

/**
 * Converts a data URI to a Blob. The given URI data must be URI-encoded and have a MIME type of
 * `text/plain`.
 *
 * @param uri URI string to convert.
 *
 * @return Blob instance.
 */
export function dataURIToBlob(uri: string) {
  const data = decodeURIComponent(uri.split(',')[1]);
  const bytes = Uint8Array.from(data, (char) => char.charCodeAt(0));
  return new Blob([bytes], { type: 'text/plain' });
}

class DownloadButtonElement extends HTMLElement {
  link: HTMLAnchorElement;

  connectedCallback() {
    this.link = this.querySelector('a')!;

    if (window.navigator.msSaveBlob) {
      this.link.addEventListener('click', this.triggerInternetExplorerDownload);
    }
  }

  /**
   * Click handler to trigger download for legacy Microsoft proprietary download.
   */
  triggerInternetExplorerDownload = (event: MouseEvent) => {
    event.preventDefault();

    const filename = this.link.getAttribute('download')!;
    const uri = this.link.getAttribute('href')!;
    const blob = new Blob([dataURIToBlob(uri)], { type: 'text/plain' });

    window.navigator.msSaveBlob?.(blob, filename);
  };
}

declare global {
  interface HTMLElementTagNameMap {
    'lg-download-button': DownloadButtonElement;
  }
}

if (!customElements.get('lg-download-button')) {
  customElements.define('lg-download-button', DownloadButtonElement);
}

export default DownloadButtonElement;
