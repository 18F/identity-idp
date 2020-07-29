import React from 'react';
import userEvent from '@testing-library/user-event';
import render from '../../../support/render';
import useHistoryParam, {
  getQueryParam,
} from '../../../../../app/javascript/app/document-capture/hooks/use-history-param';

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
  function TestComponent() {
    const [count = 0, setCount] = useHistoryParam('the count');

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

  it('syncs by setter', () => {
    const { getByText, getByDisplayValue } = render(<TestComponent />);

    userEvent.click(getByText('Increment'));

    expect(getByDisplayValue('1')).to.be.ok();
    expect(window.location.hash).to.equal('#the%20count=1');

    userEvent.click(getByText('Increment'));

    expect(getByDisplayValue('2')).to.be.ok();
    expect(window.location.hash).to.equal('#the%20count=2');
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

  // Skip reason: JSDOM doesn't currently support full history navigation.
  // Unskip prerequisite: https://github.com/jsdom/jsdom/issues/2112
  it.skip('preserves existing query parameters', () => {
    window.location.search = '?ok';
    const { getByText } = render(<TestComponent />);

    userEvent.click(getByText('Increment'));

    expect(window.location.search).to.equal('?ok');
  });

  it('encodes parameter names and values', () => {
    const { getByDisplayValue } = render(<TestComponent />);

    const input = getByDisplayValue('0');
    userEvent.clear(input);
    userEvent.type(input, 'one hundred');

    expect(window.location.hash).to.equal('#the%20count=one%20hundred');
  });
});
