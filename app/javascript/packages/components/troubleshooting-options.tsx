import type { ReactNode } from 'react';
import { BlockLink } from '@18f/identity-components';
import { useI18n } from '@18f/identity-react-i18n';
import { BlockLinkProps } from './block-link';

export type TroubleshootingOption = Omit<BlockLinkProps, 'href'> & {
  url: string;

  text: ReactNode;

  isExternal?: boolean;
};

interface TroubleshootingOptionsProps {
  headingTag?: 'h1' | 'h2' | 'h3' | 'h4' | 'h5' | 'h6';

  heading?: ReactNode;

  options: TroubleshootingOption[];

  isNewFeatures?: boolean;

  divider?: boolean;
}

function TroubleshootingOptions({
  headingTag = 'h2',
  heading,
  options,
  isNewFeatures,
  divider = true,
}: TroubleshootingOptionsProps) {
  const { t } = useI18n();

  if (!options.length) {
    return null;
  }

  const classes = ['troubleshooting-options', divider && 'troubleshooting-options--divider']
    .filter(Boolean)
    .join(' ');
  const HeadingTag = headingTag;

  return (
    <section className={classes}>
      {isNewFeatures && (
        <span className="usa-tag bg-accent-cool-darker text-uppercase display-inline-block">
          {t('components.troubleshooting_options.new_feature')}
        </span>
      )}
      <HeadingTag className="troubleshooting-options__heading">
        {heading ?? t('components.troubleshooting_options.default_heading')}
      </HeadingTag>
      <ul className="troubleshooting-options__options">
        {options.map(({ url, text, ...extraProps }, index) => (
          <li key={`tso-${index}`}>
            <BlockLink {...extraProps} href={url}>
              {text}
            </BlockLink>
          </li>
        ))}
      </ul>
    </section>
  );
}

export default TroubleshootingOptions;
