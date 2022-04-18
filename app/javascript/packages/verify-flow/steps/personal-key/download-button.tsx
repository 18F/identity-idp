import type { MouseEventHandler } from 'react';
import { Button } from '@18f/identity-components';
import type { ButtonProps } from '@18f/identity-components';

interface DownloadButtonProps {
  /**
   * Content of the downloaded file.
   */
  content: string;

  /**
   * File name to use for downloaded file.
   */
  fileName: string;
}

function DownloadButton({ content, fileName, ...buttonProps }: DownloadButtonProps & ButtonProps) {
  const download: MouseEventHandler = (event) => {
    buttonProps.onClick?.(event);

    if ('msSaveBlob' in window.navigator) {
      event.preventDefault();

      const filename = (event.target as HTMLButtonElement).getAttribute('download');
      const blob = new Blob([content], { type: 'text/plain' });

      (window.navigator as any).msSaveBlob(blob, filename);
    }
  };

  return (
    <Button
      {...buttonProps}
      href={`data:text/plain;base64,${btoa(content)}`}
      download={fileName}
      onClick={download}
    />
  );
}

export default DownloadButton;
