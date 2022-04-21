import { createContext, useContext } from 'react';
import type { ReactNode } from 'react';
import { useInstanceId } from '@18f/identity-react-hooks';

const ModalContext = createContext('');

interface ModalProps {
  children: ReactNode;
}

interface ModalHeadingProps {
  children: ReactNode;
}

interface ModalDescriptionProps {
  children: ReactNode;
}

function Modal({ children }: ModalProps) {
  const instanceId = useInstanceId();

  return (
    <ModalContext.Provider value={instanceId}>
      <div className="usa-modal-wrapper is-visible">
        <div className="usa-modal-overlay">
          <div
            role="dialog"
            className="padding-x-2 padding-y-6 modal"
            aria-labelledby={`modal-heading-${instanceId}`}
            aria-describedby={`modal-description-${instanceId}`}
          >
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
