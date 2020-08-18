import React, { createElement, useContext, useEffect } from 'react';
import { render as baseRender } from '@testing-library/react';
import UploadContext, {
  Provider as UploadContextProvider,
} from '@18f/identity-document-capture/context/upload';
import defaultUpload from '@18f/identity-document-capture/services/upload';
import render from '../../../support/render';

describe('document-capture/context/upload', () => {
  it('defaults to the default upload service', () => {
    baseRender(
      createElement(() => {
        const upload = useContext(UploadContext);
        expect(upload).to.equal(defaultUpload);
        return null;
      }),
    );
  });

  it('can be overridden with custom upload behavior', (done) => {
    render(
      <UploadContextProvider upload={(payload) => Promise.resolve({ ...payload, received: true })}>
        {createElement(() => {
          const upload = useContext(UploadContext);
          useEffect(() => {
            upload({ sent: true }).then((result) => {
              expect(result).to.deep.equal({ sent: true, received: true });
              done();
            });
          }, [upload]);
          return null;
        })}
      </UploadContextProvider>,
    );
  });

  it('can provide endpoint and csrf to make available to uploader', (done) => {
    render(
      <UploadContextProvider
        upload={(payload, { endpoint, csrf }) =>
          Promise.resolve({
            ...payload,
            receivedEndpoint: endpoint,
            receivedCSRF: csrf,
          })
        }
        csrf="example"
        endpoint="https://example.com"
      >
        {createElement(() => {
          const upload = useContext(UploadContext);
          useEffect(() => {
            upload({ sent: true }).then((result) => {
              expect(result).to.deep.equal({
                sent: true,
                receivedEndpoint: 'https://example.com',
                receivedCSRF: 'example',
              });
              done();
            });
          }, [upload]);
          return null;
        })}
      </UploadContextProvider>,
    );
  });
});
