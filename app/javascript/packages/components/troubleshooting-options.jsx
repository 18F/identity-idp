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
 * @prop {'h1'|'h2'|'h3'|'h4'|'h5'|'h6'=} headingTag
 * @prop {string} heading
 * @prop {TroubleshootingOption[]} options
 */

/**
 * @param {TroubleshootingOptionsProps} props
 */
function TroubleshootingOptions({ headingTag = 'h2', heading, options }) {
  const HeadingTag = headingTag;

  return (
    <section className="troubleshooting-options">
      <HeadingTag className="troubleshooting-options__heading">{heading}</HeadingTag>
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
