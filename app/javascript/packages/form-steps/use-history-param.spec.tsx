import { render } from '@testing-library/react';
import { renderHook } from '@testing-library/react-hooks';
import userEvent from '@testing-library/user-event';
import useHistoryParam, { getStepParam } from './use-history-param';

describe('getStepParam', () => {
  it('returns step', () => {
    const path = 'step';
    const result = getStepParam(path);

    expect(result).to.equal('step');
  });
});

describe('useHistoryParam', () => {
  function TestComponent({ initialValue }: { initialValue?: string }) {
    const [count = 0, setCount] = useHistoryParam(initialValue);

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
    await userEvent.type(input, ' 1');

    expect(window.location.hash).to.equal('#0%201');
  });

  it('syncs across instances', () => {
    const inst1 = renderHook(() => useHistoryParam());
    const inst2 = renderHook(() => useHistoryParam());

    const [, setPath1] = inst1.result.current;
    setPath1('root');

    const [path2] = inst2.result.current;
    expect(path2).to.equal('root');
  });
});
