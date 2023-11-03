/* eslint-disable react/function-component-definition */

import { renderHook, cleanup } from '@testing-library/react';
import useToggleBodyClassByPresence from './use-toggle-body-class-by-presence';

describe('useToggleBodyClassByPresence', () => {
  const ComponentOne = () => null;
  const ComponentTwo = () => null;

  afterEach(cleanup);

  it('adds body class while hook is active', () => {
    renderHook(() => useToggleBodyClassByPresence('component-one', ComponentOne));

    expect(document.body.classList.contains('component-one')).to.be.true();
  });

  it('removes body class after hook is deactivated', () => {
    const { unmount } = renderHook(() =>
      useToggleBodyClassByPresence('component-one', ComponentOne),
    );

    unmount();

    expect(document.body.classList.contains('component-one')).to.be.false();
  });

  it('does not remove body class if one of multiple instances is removed', () => {
    renderHook(() => useToggleBodyClassByPresence('component-one', ComponentOne));
    const { unmount: unmountSecond } = renderHook(() =>
      useToggleBodyClassByPresence('component-one', ComponentOne),
    );

    unmountSecond();

    expect(document.body.classList.contains('component-one')).to.be.true();
  });

  it('tracks multiple components', () => {
    const { unmount: unmountComponentOne } = renderHook(() =>
      useToggleBodyClassByPresence('component-one', ComponentOne),
    );
    const { unmount: unmountComponentTwo } = renderHook(() =>
      useToggleBodyClassByPresence('component-two', ComponentTwo),
    );

    expect(document.body.classList.contains('component-one')).to.be.true();
    expect(document.body.classList.contains('component-two')).to.be.true();

    unmountComponentOne();

    expect(document.body.classList.contains('component-one')).to.be.false();
    expect(document.body.classList.contains('component-two')).to.be.true();

    unmountComponentTwo();

    expect(document.body.classList.contains('component-one')).to.be.false();
    expect(document.body.classList.contains('component-two')).to.be.false();
  });
});
