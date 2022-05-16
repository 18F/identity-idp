import { useRef } from 'react';
import { createPortal } from 'react-dom';
import Button from './button';
import type { ButtonProps } from './button';

interface ButtonToProps extends ButtonProps {
  /**
   * URL to which the user should navigate.
   */
  url: string;

  /**
   * Form method button should submit as.
   */
  method: string;
}

/**
 * Component which renders a button that navigates to the specified URL via form, with method
 * parameterized as a hidden input and including authenticity token. The form is rendered to the
 * document root, to avoid conflicts with nested forms.
 */
function ButtonTo({ url, method, children, ...buttonProps }: ButtonToProps) {
  const formRef = useRef<HTMLFormElement>(null);
  const csrfRef = useRef<HTMLInputElement>(null);

  function submitForm() {
    const csrf = document.querySelector<HTMLMetaElement>('meta[name="csrf-token"]')?.content;
    if (csrf && csrfRef.current) {
      csrfRef.current.value = csrf;
    }
    formRef.current?.submit();
  }

  return (
    <Button {...buttonProps} onClick={submitForm}>
      {children}
      {createPortal(
        <form ref={formRef} method="post" action={url}>
          <input type="hidden" name="_method" value={method} />
          <input ref={csrfRef} type="hidden" name="authenticity_token" />
        </form>,
        document.body,
      )}
    </Button>
  );
}

export default ButtonTo;
