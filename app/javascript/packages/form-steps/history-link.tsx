import { useCallback } from 'react';
import type { MouseEventHandler } from 'react';
import { Link, Button } from '@18f/identity-components';
import type { LinkProps, ButtonProps } from '@18f/identity-components';
import useHistoryParam, { getParamURL } from './use-history-param';
import type { ParamValue } from './use-history-param';

type HistoryLinkProps = (Partial<Exclude<LinkProps, 'href'>> | Partial<ButtonProps>) & {
  /**
   * When using path fragments for maintaining history, the base path to which the current step name
   * is appended.
   */
  basePath?: string;

  /**
   * The step to which the link should navigate.
   */
  step: ParamValue;

  /**
   * Whether to render the link with the appearance of a button.
   */
  isVisualButton?: boolean;
};

/**
 * Renders a link to the given step. Enhances a Link or Button to perform client-side routing using
 * useHistoryParam hook.
 *
 * @param props Props object.
 *
 * @return Link element.
 */
function HistoryLink({ basePath, step, isVisualButton = false, ...extraProps }: HistoryLinkProps) {
  const [, setPath] = useHistoryParam(undefined, { basePath });
  const handleClick = useCallback<MouseEventHandler<Element>>(
    (event) => {
      if (
        !event.defaultPrevented &&
        !event.metaKey &&
        !event.shiftKey &&
        !event.ctrlKey &&
        !event.altKey &&
        event.button === 0
      ) {
        event.preventDefault();
        setPath(step);
      }
    },
    [basePath],
  );

  const href = getParamURL(step, { basePath });

  if (isVisualButton) {
    return <Button {...(extraProps as Partial<ButtonProps>)} href={href} onClick={handleClick} />;
  }

  return <Link {...(extraProps as Partial<LinkProps>)} href={href} onClick={handleClick} />;
}

export default HistoryLink;
