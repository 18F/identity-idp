import TipList from '@18f/identity-document-capture/components/tip-list';

import { render } from '../../../support/document-capture';

describe('document-capture/components/tip-list', () => {
  const title = 'doc_auth.tips.review_issues_id_header_text';
  const items = ['doc_auth.tips.review_issues_id_text1', 'doc_auth.tips.review_issues_id_text2'];

  it('renders title and list', () => {
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

  it('formats the title based on titleClassName', () => {
    const titleClassName = 'margin-bottom-0 margin-top-2';
    const { getByText } = render(
      <TipList titleClassName={titleClassName} title={title} items={items} translationNeeded />,
    );
    const tipsTitle = getByText('doc_auth.tips.review_issues_id_header_text');
    expect(tipsTitle.className).to.eql(titleClassName);
  });
});
