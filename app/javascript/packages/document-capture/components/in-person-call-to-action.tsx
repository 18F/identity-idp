import { useContext } from 'react';
import { Button } from '@18f/identity-components';
import { useInstanceId } from '@18f/identity-react-hooks';
import { t } from '@18f/identity-i18n';
import AnalyticsContext from '../context/analytics';
import { InPersonContext } from '../context';

interface InPersonCallToActionProps {
  altHeading?: string;
  altPrompt?: string;
  altButtonText?: string;
}

function InPersonCallToAction({ altHeading, altPrompt, altButtonText }: InPersonCallToActionProps) {
  const instanceId = useInstanceId();
  const { trackEvent } = useContext(AnalyticsContext);
  const { inPersonCtaVariantActive } = useContext(InPersonContext);

  return (
    <section
      aria-labelledby={`in-person-cta-heading-${instanceId}`}
      aria-describedby={`in-person-cta-tag-${instanceId}`}
    >
      <hr className="margin-y-5" />
      <h2 id={`in-person-cta-heading-${instanceId}`} className="margin-y-2">
        {altHeading || t('in_person_proofing.headings.cta')}
      </h2>
      <p>{altPrompt || t('in_person_proofing.body.cta.prompt_detail')}</p>
      <Button
        isBig
        isOutline
        isWide
        href="#location"
        className="margin-top-3 margin-bottom-1"
        onClick={() =>
          trackEvent('IdV: verify in person troubleshooting option clicked', {
            in_person_cta_variant: inPersonCtaVariantActive,
          })
        }
      >
        {altButtonText || t('in_person_proofing.body.cta.button')}
      </Button>
    </section>
  );
}

export default InPersonCallToAction;
