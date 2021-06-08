import sinon from 'sinon';
import userEvent from '@testing-library/user-event';
import { render } from '@testing-library/react';
import { renderHook } from '@testing-library/react-hooks';
import useButtonRole, {
  filterKeyEvents,
} from '@18f/identity-document-capture/hooks/use-button-role';

describe('document-capture/hooks/use-button-role', () => {
  describe('filterKeyEvents', () => {
    let event;
    beforeEach(() => {
      const { getByRole } = render(
        <input
          onKeyDown={(_event) => {
            event = _event;
          }}
        />,
      );
      userEvent.type(getByRole('textbox'), '{enter}');
    });

    it('calls callback for filtered key', () => {
      const callback = sinon.spy();
      filterKeyEvents(['Enter'], callback)(event);

      expect(callback).to.have.been.called();
    });

    it('does not call callback for key not included in filter', () => {
      const callback = sinon.spy();
      filterKeyEvents([' '], callback)(event);

      expect(callback).not.to.have.been.called();
    });
  });

  it('returns a function which, when called, creates a props object', () => {
    const { result } = renderHook(() => useButtonRole());

    expect(result.current()).to.have.all.keys(['role', 'onClick', 'onKeyDown']);
  });
});
