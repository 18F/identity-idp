export interface IncodeSession {
  token: string;
  interviewId?: string;
}

export interface IncodeCreateSessionOptions {
  configurationId?: string;
  externalCustomerId?: string;
  customFields?: {
    externalId?: string;
    externalCustomerId?: string;
  };
}

export interface IncodeCameraOptions {
  token: IncodeSession;
  onSuccess: () => void | Promise<void>;
  onError?: (error: unknown) => void;
}

export interface IncodeSdkInstance {
  initialize?: () => Promise<void>;
  createSession: (
    countryCode: string,
    token?: string | null,
    options?: IncodeCreateSessionOptions,
  ) => Promise<IncodeSession>;
  renderCamera: (
    side: 'front' | 'back',
    container: HTMLElement,
    options: IncodeCameraOptions,
  ) => void;
  processId: (options: { token: string }) => Promise<unknown>;
}

export interface IncodeOnBoardingGlobal {
  create: (config: { apiKey?: string; apiURL?: string }) => IncodeSdkInstance;
}

declare global {
  interface Window {
    OnBoarding?: IncodeOnBoardingGlobal;
    initializeIncodeDocumentCapture?: typeof initialize;
  }
}

export interface InitializeOptions {
  root?: ParentNode;
  onBoarding?: IncodeOnBoardingGlobal;
  navigate?: (url: string) => void;
}

function defaultNavigate(url: string) {
  window.location.href = url;
}

export async function initialize({
  root = document,
  onBoarding = window.OnBoarding,
  navigate = defaultNavigate,
}: InitializeOptions = {}) {
  const appRoot = root.querySelector<HTMLElement>('#incode-document-capture');
  const cameraContainer = root.querySelector<HTMLElement>('#incode-camera-container');

  if (!appRoot || !cameraContainer || !onBoarding) {
    return;
  }

  const {
    apiKey = '',
    apiUrl = '',
    flowId = '',
    externalId = '',
    externalCustomerId = '',
    updateUrl = '',
  } = appRoot.dataset;

  const incode = onBoarding.create({
    apiKey: apiKey || undefined,
    apiURL: apiUrl,
  });

  if (typeof incode.initialize === 'function') {
    await incode.initialize();
  }

  const session = await incode.createSession('ALL', null, {
    configurationId: flowId,
    externalCustomerId,
    customFields: {
      externalId,
      externalCustomerId,
    },
  });

  const completeSubmission = async () => {
    await incode.processId({ token: session.token });
    navigate(updateUrl);
  };

  incode.renderCamera('front', cameraContainer, {
    token: session,
    onSuccess: () => {
      incode.renderCamera('back', cameraContainer, {
        token: session,
        onSuccess: completeSubmission,
      });
    },
  });
}

if (typeof window !== 'undefined') {
  window.initializeIncodeDocumentCapture = initialize;
}

if (process.env.NODE_ENV !== 'test') {
  initialize();
}
