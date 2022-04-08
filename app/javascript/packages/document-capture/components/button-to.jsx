import { useContext, useRef } from 'react';
import { createPortal } from 'react-dom';
import { Button } from '@18f/identity-components';
import UploadContext from '../context/upload';

/** @typedef {import('@18f/identity-components/button').ButtonProps} ButtonProps */

/**
 * @typedef NativeButtonToProps
 *
 * @prop {string} url URL to which the user should navigate.
 * @prop {string} method Form method button should submit as.
 */

/**
 * @typedef {NativeButtonToProps & ButtonProps} ButtonToProps
 */

/**
 * Component which renders a button that navigates to the specified URL via form, with method
 * parameterized as a hidden input and including authenticity token. The form is rendered to the
 * document root, to avoid conflicts with nested forms.
 *
 * @param {ButtonToProps} props
 */
function ButtonTo({ url, method, children, ...buttonProps }) {
  const { csrf } = useContext(UploadContext);
  const formRef = useRef(/** @type {HTMLFormElement?} */ (null));

  return (
    <Button {...buttonProps} onClick={() => formRef.current?.submit()}>
      {children}
      {createPortal(
        <form ref={formRef} method="post" action={url}>
          <input type="hidden" name="_method" value={method} />
          {csrf && <input type="hidden" name="authenticity_token" value={csrf} />}
        </form>,
        document.body,
      )}
    </Button>
  );
}

export default ButtonTo;
