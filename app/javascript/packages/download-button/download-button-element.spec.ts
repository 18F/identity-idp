import sinon from 'sinon';
import { screen, fireEvent } from '@testing-library/dom';
import { useDefineProperty } from '@18f/identity-test-helpers';
import { dataURIToBlob } from './download-button-element';

describe('dataURIToBlob', () => {
  it('converts a data URI to equivalent Blob', async () => {
    const blob = dataURIToBlob('data:text/plain;charset=utf-8,hello%20world');

    const result = await new Promise<string>((resolve) => {
      const reader = new FileReader();
      reader.addEventListener('load', () => resolve(reader.result as string));
      reader.readAsText(blob);
    });

    expect(result).to.equal('hello world');
  });
});

describe('DownloadButtonElement', () => {
  it('does not interfere with the click event', () => {
    document.body.innerHTML = `
      <lg-download-button>
        <a href="data:text/plain;charset=utf-8,hello%20world" download="filename.txt">Download</a>
      </lg-download-button>
    `;

    const link = screen.getByRole('link', { name: 'Download' });

    const onClick = sinon.stub().callsFake((event: MouseEvent) => {
      expect(event.defaultPrevented).to.be.false();

      // Prevent default behavior, since JSDOM will otherwise throw an error on navigation.
      event.preventDefault();
    });
    window.addEventListener('click', onClick);
    fireEvent.click(link);
    window.removeEventListener('click', onClick);

    expect(onClick).to.have.been.called();
  });

  context('with legacy Microsoft proprietary download', () => {
    const defineProperty = useDefineProperty();

    it('prevents default and calls msSaveBlob', () => {
      defineProperty(window.navigator, 'msSaveBlob', { value: sinon.stub(), configurable: true });

      document.body.innerHTML = `
        <lg-download-button>
          <a href="data:text/plain;charset=utf-8,hello%20world" download="filename.txt">Download</a>
        </lg-download-button>
      `;

      const link = screen.getByRole('link', { name: 'Download' });

      const onClick = sinon.stub().callsFake((event: MouseEvent) => {
        expect(event.defaultPrevented).to.be.true();

        // Prevent default behavior, since JSDOM will otherwise throw an error on navigation.
        event.preventDefault();
      });
      window.addEventListener('click', onClick);
      fireEvent.click(link);
      window.removeEventListener('click', onClick);

      expect(onClick).to.have.been.called();
      expect(window.navigator.msSaveBlob).to.have.been.called();
    });
  });
});
