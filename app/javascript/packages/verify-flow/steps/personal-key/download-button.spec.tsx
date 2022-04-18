import sinon from 'sinon';
import { render, fireEvent, createEvent } from '@testing-library/react';
import { usePropertyValue } from '@18f/identity-test-helpers';
import DownloadButton from './download-button';

describe('DownloadButton', () => {
  it('renders a link to download the given content as file', () => {
    const { getByRole } = render(<DownloadButton fileName="example.txt" content="example" />);

    const link = getByRole('link');

    expect(link.getAttribute('download')).to.equal('example.txt');
    expect(link.getAttribute('href')).to.equal('data:text/plain;base64,ZXhhbXBsZQ==');
  });

  it('does not prevent default when clicked', () => {
    const { getByRole } = render(<DownloadButton fileName="example.txt" content="example" />);

    const link = getByRole('link');
    const clickEvent = createEvent('click', link, { bubbles: true, cancelable: true });
    fireEvent(link, clickEvent);

    expect(clickEvent.defaultPrevented).to.be.false();
  });

  it('calls onClick prop if given', () => {
    const onClick = sinon.stub();
    const { getByRole } = render(
      <DownloadButton fileName="example.txt" content="example" onClick={onClick} />,
    );

    const link = getByRole('link');
    const clickEvent = createEvent('click', link, { bubbles: true, cancelable: true });
    fireEvent(link, clickEvent);

    expect(onClick).to.have.been.called();
    expect(onClick.getCall(0).args[0].nativeEvent).to.equal(clickEvent);
  });

  context('in internet explorer', () => {
    usePropertyValue(window.navigator as any, 'msSaveBlob', sinon.stub());

    it('intercepts click to download file using proprietary API', () => {
      const onClick = sinon.stub();
      const { getByRole } = render(
        <DownloadButton fileName="example.txt" content="example" onClick={onClick} />,
      );

      const link = getByRole('link');
      const clickEvent = createEvent('click', link, { bubbles: true, cancelable: true });
      fireEvent(link, clickEvent);

      expect(onClick).to.have.been.called();
      expect(onClick.getCall(0).args[0].nativeEvent).to.equal(clickEvent);
      expect(clickEvent.defaultPrevented).to.be.true();
      expect((window.navigator as any).msSaveBlob).to.have.been.called();
    });
  });
});
