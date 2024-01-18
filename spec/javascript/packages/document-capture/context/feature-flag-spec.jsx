import { useContext } from 'react';
import { renderHook } from '@testing-library/react-hooks';
import FeatureFlagContext from '@18f/identity-document-capture/context/feature-flag';

describe('document-capture/context/feature-flag', () => {
  it('has expected default properties', () => {
    const { result } = renderHook(() => useContext(FeatureFlagContext));

    expect(result.current).to.have.keys(['exitQuestionSectionEnabled', 'selfieCaptureEnabled']);
    expect(result.current.exitQuestionSectionEnabled).to.be.a('boolean');
    expect(result.current.selfieCaptureEnabled).to.be.a('boolean');
  });
});
