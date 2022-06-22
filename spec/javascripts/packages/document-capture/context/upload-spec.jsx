import { useContext } from 'react';
import { renderHook } from '@testing-library/react-hooks';
import UploadContext, {
  Provider as UploadContextProvider,
} from '@18f/identity-document-capture/context/upload';
import defaultUpload from '@18f/identity-document-capture/services/upload';
import { useSandbox } from '@18f/identity-test-helpers';

describe('document-capture/context/upload', () => {
  const sandbox = useSandbox();

  it('defaults to the default upload service', async () => {
    const { result } = renderHook(() => useContext(UploadContext));

    expect(result.current).to.have.keys([
      'upload',
      'isMockClient',
      'statusPollInterval',
      'getStatus',
      'backgroundUploadURLs',
      'backgroundUploadEncryptKey',
      'flowPath',
      'formData',
      'csrf',
    ]);

    expect(result.current.upload).to.equal(defaultUpload);
    expect(result.current.getStatus).to.be.instanceOf(Function);
    expect(result.current.statusPollInterval).to.be.undefined();
    expect(result.current.isMockClient).to.be.false();
    expect(result.current.backgroundUploadURLs).to.deep.equal({});
    expect(result.current.backgroundUploadEncryptKey).to.be.undefined();
    expect(result.current.csrf).to.be.null();
    expect(await result.current.getStatus()).to.deep.equal({});
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

  it('can be overridden with status endpoint', async () => {
    const statusEndpoint = 'about:blank';
    const { result } = renderHook(() => useContext(UploadContext), {
      wrapper: ({ children }) => (
        <UploadContextProvider statusEndpoint={statusEndpoint} statusPollInterval={1000}>
          {children}
        </UploadContextProvider>
      ),
    });

    sandbox
      .stub(window, 'fetch')
      .withArgs(statusEndpoint)
      .resolves({ ok: true, url: statusEndpoint, json: () => Promise.resolve({ success: true }) });

    await result.current.getStatus();
    expect(result.current.statusPollInterval).to.equal(1000);
  });

  it('can be overridden with background upload URLs', () => {
    const backgroundUploadURLs = { foo: '/' };
    const { result } = renderHook(() => useContext(UploadContext), {
      wrapper: ({ children }) => (
        <UploadContextProvider backgroundUploadURLs={backgroundUploadURLs}>
          {children}
        </UploadContextProvider>
      ),
    });

    expect(result.current.backgroundUploadURLs).to.deep.equal(backgroundUploadURLs);
  });

  it('can be overridden with background upload encrypt key', async () => {
    const key = await window.crypto.subtle.generateKey(
      {
        name: 'AES-GCM',
        length: 256,
      },
      true,
      ['encrypt', 'decrypt'],
    );
    const { result } = renderHook(() => useContext(UploadContext), {
      wrapper: ({ children }) => (
        <UploadContextProvider backgroundUploadEncryptKey={key}>{children}</UploadContextProvider>
      ),
    });

    expect(result.current.backgroundUploadEncryptKey).to.equal(key);
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
