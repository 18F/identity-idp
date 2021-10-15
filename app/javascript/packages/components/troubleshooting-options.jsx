import { BlockLink } from '@18f/identity-components';

/**
 * @typedef TroubleshootingOption
 *
 * @prop {string} url
 * @prop {string} text
 * @prop {boolean} isExternal
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
      {options.map(({ url, text, isExternal }) => (
        <li key={url}>
          <BlockLink url={url} isNewTab={isExternal}>
            {text}
          </BlockLink>
        </li>
      ))}
    </section>
  );
}

export default TroubleshootingOptions;
