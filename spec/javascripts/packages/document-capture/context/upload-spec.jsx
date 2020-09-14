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
        const { upload, isMockClient } = useContext(UploadContext);
        expect(upload).to.equal(defaultUpload);
        expect(isMockClient).to.equal(false);
        return null;
      }),
    );
  });

  it('can be overridden with custom upload behavior', (done) => {
    render(
      <UploadContextProvider upload={(payload) => Promise.resolve({ ...payload, received: true })}>
        {createElement(() => {
          const { upload } = useContext(UploadContext);
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

  it('can be overridden with isMockClient value', () => {
    render(
      <UploadContextProvider isMockClient>
        {createElement(() => {
          const { isMockClient } = useContext(UploadContext);
          expect(isMockClient).to.equal(true);
          return null;
        })}
      </UploadContextProvider>,
    );
  });

  it('can provide endpoint, csrf, errorRedirects to make available to uploader', (done) => {
    render(
      <UploadContextProvider
        upload={(payload, { endpoint, csrf, errorRedirects }) =>
          Promise.resolve({
            ...payload,
            receivedEndpoint: endpoint,
            receivedCSRF: csrf,
            errorRedirects,
          })
        }
        csrf="example"
        endpoint="https://example.com"
        errorRedirects={{ 418: '#teapot' }}
      >
        {createElement(() => {
          const { upload } = useContext(UploadContext);
          useEffect(() => {
            upload({ sent: true }).then((result) => {
              expect(result).to.deep.equal({
                sent: true,
                receivedEndpoint: 'https://example.com',
                receivedCSRF: 'example',
                errorRedirects: { 418: '#teapot' },
              });
              done();
            });
          }, [upload]);
          return null;
        })}
      </UploadContextProvider>,
    );
  });

  it('can merge form data to pass to uploader', (done) => {
    render(
      <UploadContextProvider
        upload={(payload) => Promise.resolve(payload)}
        formData={{ foo: 'bar' }}
      >
        {createElement(() => {
          const { upload } = useContext(UploadContext);
          useEffect(() => {
            upload({ sent: true }).then((result) => {
              expect(result).to.deep.equal({
                sent: true,
                foo: 'bar',
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
