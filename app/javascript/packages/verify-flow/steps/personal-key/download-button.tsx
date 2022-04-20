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

export interface NavigatorWithSaveBlob extends Navigator {
  msSaveBlob: (blob: Blob, filename: string) => void;
}

export const hasProprietarySaveBlob = (
  navigator: Navigator | NavigatorWithSaveBlob,
): navigator is NavigatorWithSaveBlob => 'msSaveBlob' in navigator;

function DownloadButton({ content, fileName, ...buttonProps }: DownloadButtonProps & ButtonProps) {
  const download: MouseEventHandler = (event) => {
    buttonProps.onClick?.(event);

    if (hasProprietarySaveBlob(window.navigator)) {
      event.preventDefault();
      const blob = new Blob([content], { type: 'text/plain' });
      window.navigator.msSaveBlob(blob, fileName);
    }
  };

  return (
    <Button
      {...buttonProps}
      icon="file_download"
      href={`data:,${encodeURIComponent(content)}`}
      download={fileName}
      onClick={download}
    />
  );
}

export default DownloadButton;
