import { I18n } from '@18f/identity-i18n';
import { I18nContext } from '@18f/identity-react-i18n';
import TipList from '@18f/identity-document-capture/components/tip-list';

import { render } from '../../../support/document-capture';

describe('document-capture/components/tip-list', () => {
  it('renders title and list with i18n translation', () => {
    const title = 'doc_auth.tips.review_issues_id_header_text';
    const { getByRole, getAllByRole, getByText } = render(
      <I18nContext.Provider
        value={
          new I18n({
            strings: {
              'doc_auth.tips.review_issues_id_header_text': 'header text',
              'doc_auth.tips.review_issues_id_text1': 'list item 1',
              'doc_auth.tips.review_issues_id_text2': 'list item 2',
            },
          })
        }
      >
        <TipList
          title={title}
          items={[1, 2].map((i) => `doc_auth.tips.review_issues_id_text${i}`)}
          translationNeeded
        />
      </I18nContext.Provider>,
    );
    expect(getByRole('list')).to.be.ok();
    expect(getByText('header text')).to.be.ok();
    const lis = getAllByRole('listitem').map((item) => item.textContent);
    expect(lis).to.eql(['list item 1', 'list item 2']);
  });
  it('renders title and list without i18n translation', () => {
    const title = 'doc_auth.tips.review_issues_id_header_text';
    const items = ['doc_auth.tips.review_issues_id_text1', 'doc_auth.tips.review_issues_id_text2'];
    const { getByRole, getAllByRole, getByText } = render(
      <TipList title={title} items={items} translationNeeded />,
    );
    expect(getByRole('list')).to.be.ok();
    expect(getByText('doc_auth.tips.review_issues_id_header_text')).to.be.ok();
    const lis = getAllByRole('listitem').map((item) => item.textContent);
    expect(lis).to.eql([
      'doc_auth.tips.review_issues_id_text1',
      'doc_auth.tips.review_issues_id_text2',
    ]);
  });
});
