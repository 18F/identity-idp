import useI18n from '../hooks/use-i18n';

/** @typedef {import('react').ReactNode} ReactNode */

/**
 * @typedef BlockLinkProps
 *
 * @prop {string} url Link destination.
 * @prop {boolean=} isExternal Whether link directs to external URL.
 * @prop {ReactNode} children Child elements.
 */

const isSameHost = (url) => new URL(url, window.location.href).host === window.location.host;

/**
 * @param {BlockLinkProps} props
 */
function BlockLink({ url, children, isExternal = !isSameHost(url) }) {
  const { t } = useI18n();

  return (
    <a href={url} className="usa-link block-link" target={isExternal ? '_blank' : undefined}>
      {children}
      {isExternal && (
        <>
          {' '}
          <svg
            xmlns="http://www.w3.org/2000/svg"
            height="10"
            viewBox="0 0 64 55"
            focusable="false"
            aria-hidden="true"
          >
            <path
              d="M35.226 5c.333 0 .605.106.818.32s.319.485.319.816v2.273c0 .332-.107.604-.32.817s-.484.32-.817.32H10.227c-1.562 0-2.9.555-4.013 1.668s-1.669 2.45-1.669 4.013v29.545c0 1.563.556 2.9 1.669 4.013s2.45 1.668 4.013 1.668h29.546c1.562 0 2.9-.555 4.013-1.668a5.47 5.47 0 0 0 1.668-4.013V33.41c0-.332.106-.604.32-.817s.484-.32.816-.32h2.273c.331 0 .604.107.817.32s.32.485.32.818v11.363C50 47.591 49 50 46.999 52s-4.41 3.001-7.226 3.001H10.227C7.41 55 5.001 54 3 51.999s-3-4.41-3-7.226V15.227c0-2.817 1-5.226 3-7.226S7.41 5 10.227 5zm26.46-5c.627 0 1.17.229 1.627.686s.687 1 .687 1.626v18.501c0 .626-.229 1.168-.687 1.626a2.22 2.22 0 0 1-1.626.687c-.626 0-1.168-.23-1.626-.687l-6.36-6.36-23.558 23.56c-.24.24-.518.36-.831.36s-.59-.12-.831-.36l-4.12-4.12a1.142 1.142 0 0 1-.361-.831c0-.313.12-.59.361-.83l23.559-23.56-6.36-6.36c-.457-.457-.686-1-.686-1.626s.229-1.168.687-1.626 1-.686 1.625-.686z"
              fill="currentColor"
            />
          </svg>
          <span className="usa-sr-only">{t('links.new_window')}</span>
        </>
      )}
      <svg
        xmlns="http://www.w3.org/2000/svg"
        viewBox="0 0 5.2 8.91"
        focusable="false"
        aria-hidden="true"
        className="block-link__arrow"
      >
        <path
          d="M5.11 4.66L1 8.82a.36.36 0 01-.21.09.31.31 0 01-.2-.09l-.5-.45a.29.29 0 01-.09-.2A.36.36 0 01.09 8L3.6 4.45.09 1A.36.36 0 010 .74a.31.31 0 01.09-.2L.54.09A.31.31 0 01.74 0 .36.36 0 011 .09l4.11 4.16a.31.31 0 01.09.2.31.31 0 01-.09.21z"
          fill="currentColor"
        />
      </svg>
    </a>
  );
}

export default BlockLink;
