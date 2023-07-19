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
      'flowPath',
      'formData',
    ]);

    expect(result.current.upload).to.equal(defaultUpload);
    expect(result.current.getStatus).to.be.instanceOf(Function);
    expect(result.current.statusPollInterval).to.be.undefined();
    expect(result.current.isMockClient).to.be.false();
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

    const response = new Response(JSON.stringify({ success: true }));
    sandbox.stub(response, 'url').get(() => statusEndpoint);
    sandbox.stub(global, 'fetch').withArgs(statusEndpoint).resolves(response);

    await result.current.getStatus();
    expect(result.current.statusPollInterval).to.equal(1000);
  });

  it('provides endpoint to custom uploader', async () => {
    const { result } = renderHook(() => useContext(UploadContext), {
      wrapper: ({ children }) => (
        <UploadContextProvider
          upload={(payload, { endpoint }) =>
            Promise.resolve({
              ...payload,
              receivedEndpoint: endpoint,
            })
          }
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
