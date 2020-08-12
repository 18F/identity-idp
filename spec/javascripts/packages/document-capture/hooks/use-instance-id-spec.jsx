import React from 'react';
import useInstanceId from '@18f/identity-document-capture/hooks/use-instance-id';
import render from '../../../support/render';

describe('document-capture/hooks/use-instance-id', () => {
  function TestComponent() {
    const instanceId = useInstanceId();

    return `${typeof instanceId}${instanceId}`;
  }

  it('returns a unique string id', () => {
    const { getByText } = render(
      <>
        <span>First</span>
        <TestComponent />
        <span>Second</span>
        <TestComponent />
      </>,
    );

    const first = getByText('First').nextSibling.nodeValue;
    const second = getByText('Second').nextSibling.nodeValue;
    expect(first).to.match(/^string/);
    expect(second).to.match(/^string/);
    expect(first).to.not.equal(second);
  });
});
