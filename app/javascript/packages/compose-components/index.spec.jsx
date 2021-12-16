import { createContext, useContext } from 'react';
import { render } from '@testing-library/react';
import { composeComponents } from './index.js';

describe('composeComponents', () => {
  it('composes components', () => {
    const FirstContext = createContext(null);
    const SecondContext = createContext(null);
    function AppRoot() {
      return (
        <>
          {useContext(FirstContext)}
          {useContext(SecondContext)}
        </>
      );
    }

    const ComposedComponent = composeComponents(
      [FirstContext.Provider, { value: 1 }],
      [SecondContext.Provider, { value: 2 }],
      [({ children }) => <>{children}3</>],
      AppRoot,
    );

    const { getByText } = render(<ComposedComponent />);

    expect(getByText('123')).to.be.ok();
  });
});
