import useSandbox from './use-sandbox';

function useAnalytics() {
  const sandbox = useSandbox();
  const trackEvent = sandbox.stub<Parameters<typeof trackEvent>, ReturnType<typeof trackEvent>>();

  beforeEach(() => {
    document.body.insertAdjacentHTML(
      'beforeend',
      '<script type="application/json" data-config>{"analyticsEndpoint":"/analytics"}</script>',
    );

    sandbox.stub(global.navigator, 'sendBeacon').callsFake((_url, data) => {
      const { event, payload } = JSON.parse(data as string);
      trackEvent(event, payload);
      return true;
    });
  });

  return trackEvent;
}

export default useAnalytics;
