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
 * @prop {string=} headingTag
 * @prop {string} headingText
 * @prop {TroubleshootingOption[]} options
 */

/**
 * @param {TroubleshootingOptionsProps} props
 */
function TroubleshootingOptions({ headingTag = 'h2', headingText, options }) {
  const HeadingTag = headingTag;

  return (
    <section className="troubleshooting-options">
      <HeadingTag className="troubleshooting-options__heading">{headingText}</HeadingTag>
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
