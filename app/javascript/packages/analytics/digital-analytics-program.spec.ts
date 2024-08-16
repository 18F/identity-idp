import { useDefineProperty } from '@18f/identity-test-helpers';

describe('digital analytics program', () => {
  const defineProperty = useDefineProperty();

  it('initializes gracefully with the expected page markup', async () => {
    // The DAP script interchangeably references values on `window` and as unprefixed globals. Our
    // test environment doesn't currently support passthrough values from global to window, so the
    // following simulates the expected behavior in the browser.
    defineProperty(global, 'dataLayer', {
      configurable: true,
      get() {
        return (window as any).dataLayer;
      },
    });

    document.body.innerHTML =
      '<script src="dap.js?agency=GSA&subagency=TTS" id="_fed_an_ua_tag"></script>';

    // Ignore reason: The tests currently run as a sort of faked ESM, so while the package isn't
    // technically a module, the import statement below is converted automatically to CommonJS.
    //
    // @ts-ignore
    await import('./digital-analytics-program.js');
  });
});
