import { BlockLink } from '@18f/identity-components';
import { useI18n } from '@18f/identity-react-i18n';

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
 * @prop {string=} heading
 * @prop {TroubleshootingOption[]} options
 * @prop {boolean=} isNewFeatures
 */

/**
 * @param {TroubleshootingOptionsProps} props
 */
function TroubleshootingOptions({ headingTag = 'h2', heading, options, isNewFeatures }) {
  const { t } = useI18n();

  const HeadingTag = headingTag;

  return (
    <section
      className={['troubleshooting-options', isNewFeatures && 'troubleshooting-options__no-bar']
        .filter(Boolean)
        .join(' ')}
    >
      {isNewFeatures && (
        <>
          <div className="margin-top-3">
            <span
              className="usa-tag bg-accent-cool-darker text-uppercase"
              data-testid="new-features-tag"
            >
              {t('components.troubleshooting_options.new_feature')}
            </span>
          </div>
        </>
      )}
      <HeadingTag className="troubleshooting-options__heading">
        {heading ?? t('components.troubleshooting_options.default_heading')}
      </HeadingTag>
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
