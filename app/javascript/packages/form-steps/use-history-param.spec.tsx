import { render } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import useHistoryParam, { getQueryParam } from './use-history-param';

describe('getQueryParam', () => {
  const queryString = 'a&b=Hello%20world&c';

  it('returns null does not exist', () => {
    const value = getQueryParam(queryString, 'd');

    expect(value).to.be.null();
  });

  it('returns decoded value of parameter', () => {
    const value = getQueryParam(queryString, 'b');

    expect(value).to.equal('Hello world');
  });

  it('defaults to empty string for empty value', () => {
    const value = getQueryParam(queryString, 'c');

    expect(value).to.equal('');
  });
});

describe('useHistoryParam', () => {
  function TestComponent({ initialValue }: { initialValue?: string | null }) {
    const [count = 0, setCount] = useHistoryParam('the count', initialValue);

    return (
      <>
        {/* Disable reason: https://github.com/jsx-eslint/eslint-plugin-jsx-a11y/issues/566 */}
        {/* eslint-disable-next-line jsx-a11y/label-has-associated-control */}
        <label>
          Count: <input value={count} onChange={(event) => setCount(event.target.value)} />
        </label>
        <button type="button" onClick={() => setCount(count + 1)}>
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
    window.location.hash = '#the%20count=5';
    const { getByDisplayValue } = render(<TestComponent />);

    expect(getByDisplayValue('5')).to.be.ok();
  });

  it('accepts an initial value', () => {
    const { getByDisplayValue } = render(<TestComponent initialValue="5" />);

    expect(window.location.hash).to.equal('#the%20count=5');
    expect(getByDisplayValue('5')).to.be.ok();
  });

  it('accepts empty initial value', () => {
    const { getByDisplayValue } = render(<TestComponent initialValue={null} />);

    expect(window.location.hash).to.equal('');
    expect(getByDisplayValue('0')).to.be.ok();
  });

  it('syncs by setter', () => {
    const { getByText, getByDisplayValue } = render(<TestComponent />);

    userEvent.click(getByText('Increment'));

    expect(getByDisplayValue('1')).to.be.ok();
    expect(window.location.hash).to.equal('#the%20count=1');

    userEvent.click(getByText('Increment'));

    expect(getByDisplayValue('2')).to.be.ok();
    expect(window.location.hash).to.equal('#the%20count=2');
  });

  it('scrolls to top on programmatic history manipulation', () => {
    const { getByText } = render(<TestComponent />);

    window.scrollX = 100;
    window.scrollY = 100;

    userEvent.click(getByText('Increment'));

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

    userEvent.click(getByText('Increment'));

    expect(getByDisplayValue('1')).to.be.ok();
    expect(window.location.hash).to.equal('#the%20count=1');

    userEvent.click(getByText('Increment'));

    expect(getByDisplayValue('2')).to.be.ok();
    expect(window.location.hash).to.equal('#the%20count=2');

    window.history.back();

    expect(await findByDisplayValue('1')).to.be.ok();
    expect(window.location.hash).to.equal('#the%20count=1');

    window.history.back();

    expect(await findByDisplayValue('0')).to.be.ok();
    expect(window.location.hash).to.equal('');
  });

  it('encodes parameter names and values', () => {
    const { getByDisplayValue } = render(<TestComponent />);

    const input = getByDisplayValue('0');
    userEvent.clear(input);
    userEvent.type(input, 'one hundred');

    expect(window.location.hash).to.equal('#the%20count=one%20hundred');
  });
});
