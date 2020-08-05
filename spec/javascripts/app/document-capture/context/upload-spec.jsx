import React, { createElement, useContext, useEffect } from 'react';
import { render as baseRender } from '@testing-library/react';
import render from '../../../support/render';
import UploadContext, {
  Provider as UploadContextProvider,
} from '../../../../../app/javascript/app/document-capture/context/upload';
import defaultUpload from '../../../../../app/javascript/app/document-capture/services/upload';

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

  it('can be provide csrf to make available to uploader', (done) => {
    render(
      <UploadContextProvider
        upload={(payload, csrf) => Promise.resolve({ ...payload, receivedCSRF: csrf })}
        csrf="example"
      >
        {createElement(() => {
          const upload = useContext(UploadContext);
          useEffect(() => {
            upload({ sent: true }).then((result) => {
              expect(result).to.deep.equal({ sent: true, receivedCSRF: 'example' });
              done();
            });
          }, [upload]);
          return null;
        })}
      </UploadContextProvider>,
    );
  });
});
