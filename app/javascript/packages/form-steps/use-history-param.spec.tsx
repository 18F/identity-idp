import sinon from 'sinon';
import { render } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { useDefineProperty } from '@18f/identity-test-helpers';
import useHistoryParam, { getStepParam } from './use-history-param';

describe('getStepParam', () => {
  it('returns step', () => {
    const path = 'step';
    const result = getStepParam(path);

    expect(result).to.equal('step');
  });

  context('with subpath', () => {
    it('returns step', () => {
      const path = 'step/subpath';
      const result = getStepParam(path);

      expect(result).to.equal('step');
    });
  });

  context('with trailing or leading slashes', () => {
    it('returns step', () => {
      const path = '/step/';
      const result = getStepParam(path);

      expect(result).to.equal('step');
    });
  });
});

describe('useHistoryParam', () => {
  const sandbox = sinon.createSandbox();
  const defineProperty = useDefineProperty();

  function TestComponent({ initialValue, basePath }: { initialValue?: string; basePath?: string }) {
    const [count = 0, setCount] = useHistoryParam(initialValue, { basePath });

    return (
      <>
        {/* Disable reason: https://github.com/jsx-eslint/eslint-plugin-jsx-a11y/issues/566 */}
        {/* eslint-disable-next-line jsx-a11y/label-has-associated-control */}
        <label>
          Count: <input value={count} onChange={(event) => setCount(event.target.value)} />
        </label>
        <button type="button" onClick={() => setCount(String(Number(count) + 1))}>
          Increment
        </button>
      </>
    );
  }

  let originalHash;

  beforeEach(() => {
    originalHash = window.location.hash;
  });

  afterEach(() => {
    window.location.hash = originalHash;
    sandbox.restore();
  });

  it('returns undefined value if absent from initial URL', () => {
    const { getByDisplayValue } = render(<TestComponent />);

    expect(getByDisplayValue('0')).to.be.ok();
  });

  it('returns initial value if present in initial URL', () => {
    window.location.hash = '#5';
    const { getByDisplayValue } = render(<TestComponent />);

    expect(getByDisplayValue('5')).to.be.ok();
  });

  it('syncs by setter', async () => {
    const { getByText, getByDisplayValue } = render(<TestComponent />);

    await userEvent.click(getByText('Increment'));

    expect(getByDisplayValue('1')).to.be.ok();
    expect(window.location.hash).to.equal('#1');

    await userEvent.click(getByText('Increment'));

    expect(getByDisplayValue('2')).to.be.ok();
    expect(window.location.hash).to.equal('#2');
  });

  it('scrolls to top on programmatic history manipulation', async () => {
    const { getByText } = render(<TestComponent />);

    window.scrollX = 100;
    window.scrollY = 100;

    await userEvent.click(getByText('Increment'));

    expect(window.scrollX).to.equal(0);
    expect(window.scrollY).to.equal(0);

    window.scrollX = 100;
    window.scrollY = 100;

    window.history.back();

    expect(window.scrollX).to.equal(100);
    expect(window.scrollY).to.equal(100);
  });

  it('syncs by history events', async () => {
    const { getByText, getByDisplayValue, findByDisplayValue } = render(<TestComponent />);

    await userEvent.click(getByText('Increment'));

    expect(getByDisplayValue('1')).to.be.ok();
    expect(window.location.hash).to.equal('#1');

    await userEvent.click(getByText('Increment'));

    expect(getByDisplayValue('2')).to.be.ok();
    expect(window.location.hash).to.equal('#2');

    window.history.back();

    expect(await findByDisplayValue('1')).to.be.ok();
    expect(window.location.hash).to.equal('#1');

    window.history.back();

    expect(await findByDisplayValue('0')).to.be.ok();
    expect(window.location.hash).to.equal('');
  });

  it('encodes parameter names and values', async () => {
    const { getByDisplayValue } = render(<TestComponent />);

    const input = getByDisplayValue('0');
    await userEvent.clear(input);
    await userEvent.type(input, 'one hundred');

    expect(window.location.hash).to.equal('#one%20hundred');
  });

  Object.entries({
    'with basePath': '/base/',
    'with basePath, no trailing slash': '/base',
  }).forEach(([description, basePath]) => {
    context(description, () => {
      context('without initial value', () => {
        beforeEach(() => {
          const history: string[] = [basePath];
          defineProperty(window, 'location', {
            value: {
              get pathname() {
                return history[history.length - 1];
              },
            },
          });

          sandbox.stub(window, 'history').value(
            Object.assign(history, {
              pushState(_data, _unused, url: string) {
                history.push(url as string);
              },
              replaceState(_data, _unused, url: string) {
                history[history.length - 1] = url as string;
              },
              back() {
                history.pop();
                window.dispatchEvent(new CustomEvent('popstate'));
              },
            }),
          );
        });

        it('returns undefined value', () => {
          const { getByDisplayValue } = render(<TestComponent basePath={basePath} />);

          expect(getByDisplayValue('0')).to.be.ok();
        });

        it('syncs by setter', async () => {
          const { getByText, getByDisplayValue } = render(<TestComponent basePath={basePath} />);

          await userEvent.click(getByText('Increment'));

          expect(getByDisplayValue('1')).to.be.ok();
          expect(window.location.pathname).to.equal('/base/1');

          await userEvent.click(getByText('Increment'));

          expect(getByDisplayValue('2')).to.be.ok();
          expect(window.location.pathname).to.equal('/base/2');
        });

        it('syncs by history events', async () => {
          const { getByText, getByDisplayValue, findByDisplayValue } = render(
            <TestComponent basePath="/base/" />,
          );

          await userEvent.click(getByText('Increment'));

          expect(getByDisplayValue('1')).to.be.ok();
          expect(window.location.pathname).to.equal('/base/1');

          await userEvent.click(getByText('Increment'));

          expect(getByDisplayValue('2')).to.be.ok();
          expect(window.location.pathname).to.equal('/base/2');

          window.history.back();

          expect(await findByDisplayValue('1')).to.be.ok();
          expect(window.location.pathname).to.equal('/base/1');

          window.history.back();

          expect(await findByDisplayValue('0')).to.be.ok();
          expect(window.location.pathname).to.equal(basePath);
        });

        context('with initial provided value', () => {
          it('returns initial value', () => {
            const { getByDisplayValue } = render(
              <TestComponent initialValue="1" basePath={basePath} />,
            );

            expect(getByDisplayValue('1')).to.be.ok();
          });

          it('syncs to URL', () => {
            render(<TestComponent initialValue="1" basePath={basePath} />);

            expect(window.location.pathname).to.equal('/base/1');
            expect(window.history.length).to.equal(1);
          });
        });
      });

      context('with initial URL value', () => {
        beforeEach(() => {
          defineProperty(window, 'location', {
            value: {
              get pathname() {
                return '/base/5/';
              },
            },
          });
        });

        it('returns initial value', () => {
          const { getByDisplayValue } = render(<TestComponent basePath={basePath} />);

          expect(getByDisplayValue('5')).to.be.ok();
        });
      });

      context('with initial URL value, no trailing slash', () => {
        beforeEach(() => {
          defineProperty(window, 'location', {
            value: {
              get pathname() {
                return '/base/5';
              },
            },
          });
        });

        it('returns initial value', () => {
          const { getByDisplayValue } = render(<TestComponent basePath={basePath} />);

          expect(getByDisplayValue('5')).to.be.ok();
        });
      });
    });
  });
});
