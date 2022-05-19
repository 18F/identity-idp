import { useCallback } from 'react';
import type { MouseEventHandler } from 'react';
import { Link } from '@18f/identity-components';
import type { LinkProps } from '@18f/identity-components';
import useHistoryParam, { getParamURL } from './use-history-param';

type HistoryLinkProps = Partial<LinkProps> & {
  basePath?: string;

  step: string;
};

function HistoryLink({ basePath, step, ...linkProps }: HistoryLinkProps) {
  const [, setPath] = useHistoryParam(undefined, { basePath });
  const handleClick = useCallback<MouseEventHandler<HTMLAnchorElement>>(
    (event) => {
      linkProps.onClick?.(event);

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

  return <Link {...linkProps} href={getParamURL(step, { basePath })} onClick={handleClick} />;
}

export default HistoryLink;
