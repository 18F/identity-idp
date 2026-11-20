import sinon from 'sinon';
import {
  initialize,
  type IncodeCameraOptions,
  type IncodeOnBoardingGlobal,
  type IncodeSdkInstance,
  type IncodeSession,
} from '../../../app/javascript/packs/incode-document-capture';

describe('incode-document-capture', () => {
  const externalId = 'dcs-uuid-1234';
  const externalCustomerId = 'user-uuid-5678';
  const apiKey = 'test-api-key';
  const apiUrl = 'https://demo-api.incodesmile.com';
  const flowId = 'flow-123';
  const updateUrl = 'https://example.com/verify/incode/document_capture_update';
  const session: IncodeSession = { token: 'incode-session-token' };

  afterEach(() => {
    document.body.innerHTML = '';
  });

  function buildPage() {
    document.body.innerHTML = `
      <div
        id="incode-document-capture"
        data-api-key="${apiKey}"
        data-api-url="${apiUrl}"
        data-flow-id="${flowId}"
        data-external-id="${externalId}"
        data-external-customer-id="${externalCustomerId}"
        data-update-url="${updateUrl}"
      >
        <div id="incode-camera-container"></div>
      </div>
    `;

    return {
      cameraContainer: document.querySelector<HTMLElement>('#incode-camera-container')!,
    };
  }

  function createMockOnBoarding() {
    const sdkInstance = {
      initialize: sinon.stub().resolves(),
      createSession: sinon.stub().resolves(session),
      renderCamera: sinon.stub(),
      processId: sinon.stub().resolves({ success: true }),
    };

    const onBoarding: IncodeOnBoardingGlobal = {
      create: sinon.stub().returns(sdkInstance as unknown as IncodeSdkInstance),
    };

    return { onBoarding, sdkInstance };
  }

  it('creates an Incode session with externalId and externalCustomerId', async () => {
    buildPage();
    const { onBoarding, sdkInstance } = createMockOnBoarding();
    const navigate = sinon.stub();

    await initialize({ onBoarding, navigate });

    expect(onBoarding.create).to.have.been.calledOnceWithExactly({
      apiKey,
      apiURL: apiUrl,
    });
    expect(sdkInstance.initialize).to.have.been.calledOnce();
    expect(sdkInstance.createSession).to.have.been.calledOnceWithExactly('ALL', null, {
      configurationId: flowId,
      externalCustomerId,
      customFields: {
        externalId,
        externalCustomerId,
      },
    });
  });

  it('captures front and back of State ID, processes ID, and redirects to updateUrl', async () => {
    const { cameraContainer } = buildPage();
    const { onBoarding, sdkInstance } = createMockOnBoarding();
    const navigate = sinon.stub();

    await initialize({ onBoarding, navigate });

    expect(sdkInstance.renderCamera).to.have.been.calledOnce();
    expect(sdkInstance.renderCamera.firstCall.args[0]).to.equal('front');
    expect(sdkInstance.renderCamera.firstCall.args[1]).to.equal(cameraContainer);

    const frontOptions = sdkInstance.renderCamera.firstCall.args[2] as IncodeCameraOptions;
    expect(frontOptions.token).to.equal(session);
    frontOptions.onSuccess();

    expect(sdkInstance.renderCamera).to.have.been.calledTwice();
    expect(sdkInstance.renderCamera.secondCall.args[0]).to.equal('back');
    expect(sdkInstance.renderCamera.secondCall.args[1]).to.equal(cameraContainer);

    const backOptions = sdkInstance.renderCamera.secondCall.args[2] as IncodeCameraOptions;
    expect(backOptions.token).to.equal(session);
    await backOptions.onSuccess();

    expect(sdkInstance.processId).to.have.been.calledOnceWithExactly({
      token: session.token,
    });
    expect(navigate).to.have.been.calledOnceWithExactly(updateUrl);
  });

  it('is a no-op when required DOM elements or OnBoarding SDK are not present', async () => {
    document.body.innerHTML = '<div></div>';
    const navigate = sinon.stub();

    await initialize({ navigate });

    expect(navigate).not.to.have.been.called();
  });
});
