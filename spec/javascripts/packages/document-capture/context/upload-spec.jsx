import React, { useContext } from 'react';
import { renderHook } from '@testing-library/react-hooks';
import UploadContext, {
  Provider as UploadContextProvider,
} from '@18f/identity-document-capture/context/upload';
import defaultUpload from '@18f/identity-document-capture/services/upload';

describe('document-capture/context/upload', () => {
  it('defaults to the default upload service', () => {
    const { result } = renderHook(() => useContext(UploadContext));
    const { upload, isMockClient } = result.current;

    expect(upload).to.equal(defaultUpload);
    expect(isMockClient).to.equal(false);
  });

  it('can be overridden with custom upload behavior', async () => {
    const { result } = renderHook(() => useContext(UploadContext), {
      wrapper: ({ children }) => (
        <UploadContextProvider
          upload={(payload) => Promise.resolve({ ...payload, received: true })}
        >
          {children}
        </UploadContextProvider>
      ),
    });

    const uploadResult = await result.current.upload({ sent: true });
    expect(uploadResult).to.deep.equal({ sent: true, received: true });
  });

  it('can be overridden with isMockClient value', () => {
    const { result } = renderHook(() => useContext(UploadContext), {
      wrapper: ({ children }) => (
        <UploadContextProvider isMockClient>{children}</UploadContextProvider>
      ),
    });

    expect(result.current.isMockClient).to.be.true();
  });

  it('can provide endpoint and csrf to make available to uploader', async () => {
    const { result } = renderHook(() => useContext(UploadContext), {
      wrapper: ({ children }) => (
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
          {children}
        </UploadContextProvider>
      ),
    });

    const uploadResult = await result.current.upload({ sent: true });
    expect(uploadResult).to.deep.equal({
      sent: true,
      receivedEndpoint: 'https://example.com',
      receivedCSRF: 'example',
    });
  });

  it('can merge form data to pass to uploader', async () => {
    const { result } = renderHook(() => useContext(UploadContext), {
      wrapper: ({ children }) => (
        <UploadContextProvider
          upload={(payload) => Promise.resolve(payload)}
          formData={{ foo: 'bar' }}
        >
          {children}
        </UploadContextProvider>
      ),
    });

    const uploadResult = await result.current.upload({ sent: true });
    expect(uploadResult).to.deep.equal({
      sent: true,
      foo: 'bar',
    });
  });
});
