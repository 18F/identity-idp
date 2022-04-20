import { createContext, useContext } from 'react';
import type { ReactNode } from 'react';
import { FullScreen } from '@18f/identity-components';
import { useInstanceId } from '@18f/identity-react-hooks';

const ModalContext = createContext('');

interface ModalProps {
  /**
   * Callback invoked in response to user interaction indicating a request to close the modal.
   */
  onRequestClose?: () => void;

  /**
   * Modal content.
   */
  children: ReactNode;
}

interface ModalHeadingProps {
  /**
   * Heading text.
   */
  children: ReactNode;
}

interface ModalDescriptionProps {
  /**
   * Description text.
   */
  children: ReactNode;
}

function Modal({ children, onRequestClose }: ModalProps) {
  const instanceId = useInstanceId();

  return (
    <ModalContext.Provider value={instanceId}>
      <FullScreen
        labelledBy={`modal-heading-${instanceId}`}
        describedBy={`modal-description-${instanceId}`}
        bgColor="none"
        hideCloseButton
        onRequestClose={onRequestClose}
      >
        <div className="usa-modal-wrapper is-visible">
          <div className="usa-modal-overlay">
            <div className="padding-x-2 padding-y-6 modal">
              <div className="modal-center">
                <div className="modal-content">
                  <div className="padding-y-8 padding-x-2 tablet:padding-x-8 cntnr-skinny bg-white radius-lg">
                    {children}
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </FullScreen>
    </ModalContext.Provider>
  );
}

Modal.Heading = ({ children }: ModalHeadingProps) => {
  const instanceId = useContext(ModalContext);

  return (
    <h2 id={`modal-heading-${instanceId}`} className="margin-top-0 margin-bottom-2">
      {children}
    </h2>
  );
};

Modal.Description = ({ children }: ModalDescriptionProps) => {
  const instanceId = useContext(ModalContext);

  return (
    <p id={`modal-description-${instanceId}`} className="margin-bottom-4">
      {children}
    </p>
  );
};

export default Modal;
