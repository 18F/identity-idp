import TipList from '@18f/identity-document-capture/components/tip-list';

import { render } from '../../../support/document-capture';

describe('document-capture/components/tip-list', () => {
  it('renders title and list', () => {
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
