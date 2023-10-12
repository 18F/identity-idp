import { FieldsetHTMLAttributes, ReactNode } from 'react';

export interface FieldSetProps extends FieldsetHTMLAttributes<HTMLFieldSetElement> {
  /**
   * Footer contents.
   */
  children: ReactNode;

  legend?: string;
}

function FieldSet({ legend, children }: FieldSetProps) {
  return (
    <fieldset className="usa-fieldset">
      {legend && <legend className="usa-fieldset">{legend}</legend>}
      {children}
    </fieldset>
  );
}

export default FieldSet;
