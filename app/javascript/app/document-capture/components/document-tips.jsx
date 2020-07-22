import React from 'react';
import PropTypes from 'prop-types';
import Accordion from './accordion';
import useI18n from '../hooks/use-i18n';

function DocumentTips({ sample }) {
  const t = useI18n();

  const title = (
    <>
      <strong>{t('doc_auth.tips.title')}</strong>
      {` ${t('doc_auth.tips.title_more')}`}
    </>
  );

  return (
    <Accordion title={title}>
      <strong>{t('doc_auth.tips.header_text')}</strong>
      <ul>
        <li>{t('doc_auth.tips.text1')}</li>
        <li>{t('doc_auth.tips.text2')}</li>
        <li>{t('doc_auth.tips.text3')}</li>
        <li>{t('doc_auth.tips.text4')}</li>
        <li>{t('doc_auth.tips.text5')}</li>
        <li>{t('doc_auth.tips.text6')}</li>
        <li>{t('doc_auth.tips.text7')}</li>
      </ul>
      {!!sample && <div className="center">{sample}</div>}
    </Accordion>
  );
}

DocumentTips.propTypes = {
  sample: PropTypes.node,
};

DocumentTips.defaultProps = {
  sample: null,
};

export default DocumentTips;
