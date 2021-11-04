import { BlockLink } from '@18f/identity-components';

/**
 * @typedef TroubleshootingOption
 *
 * @prop {string} url
 * @prop {string|JSX.Element} text
 * @prop {boolean=} isExternal
 */

/**
 * @typedef TroubleshootingOptionsProps
 *
 * @prop {string} heading
 * @prop {TroubleshootingOption[]} options
 */

/**
 * @param {TroubleshootingOptionsProps} props
 */
function TroubleshootingOptions({ heading, options }) {
  return (
    <section className="troubleshooting-options">
      <h2>{heading}</h2>
      <ul className="troubleshooting-options__options">
        {options.map(({ url, text, isExternal }) => (
          <li key={url}>
            <BlockLink url={url} isNewTab={isExternal}>
              {text}
            </BlockLink>
          </li>
        ))}
      </ul>
    </section>
  );
}

export default TroubleshootingOptions;
