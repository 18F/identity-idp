import React, { useEffect, useRef, useMemo } from 'react';
import PropTypes from 'prop-types';
import BaseAccordion from '../../components/accordion';
import useI18n from '../hooks/use-i18n';
import Image from './image';

function Accordion({ title, children }) {
  const elementRef = useRef(null);
  const instanceId = useMemo(() => {
    Accordion.instances += 1;
    return Accordion.instances;
  }, []);
  const t = useI18n();
  useEffect(() => {
    new BaseAccordion(elementRef.current).setup();
  }, []);

  const contentId = `accordion-content-${instanceId}`;

  return (
    <div ref={elementRef} className="accordion mb4 col-12 fs-16p">
      <div aria-describedby={contentId} className="accordion-header">
        <div
          aria-controls={contentId}
          aria-expanded="false"
          role="button"
          tabIndex={0}
          className="accordion-header-controls py1 px2 mt-tiny mb-tiny"
        >
          <span className="mb0 mr2">{title}</span>
          <Image
            assetPath="plus.svg"
            alt={t('image_description.accordian_plus_buttom')}
            width={16}
            className="plus-icon display-none"
          />
          <Image
            assetPath="minus.svg"
            alt={t('image_description.accordian_minus_buttom')}
            width={16}
            className="minus-icon display-none"
          />
        </div>
      </div>
      <div
        id={contentId}
        className="accordion-content clearfix pt1"
        role="region"
        aria-hidden="true"
      >
        <div className="px2">{children}</div>
        <div
          className="py1 accordion-footer"
          aria-controls={contentId}
          role="button"
          tabIndex={0}
        >
          <div className="pb-tiny pt-tiny">
            <Image
              assetPath="up-carat-thin.svg"
              alt=""
              width={14}
              className="mr1"
            />
            {t('users.personal_key.close')}
          </div>
        </div>
      </div>
    </div>
  );
}

Accordion.instances = 0;

Accordion.propTypes = {
  title: PropTypes.node.isRequired,
  children: PropTypes.node.isRequired,
};

export default Accordion;
