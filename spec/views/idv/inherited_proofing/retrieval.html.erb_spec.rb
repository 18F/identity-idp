require 'rails_helper'

describe 'idv/inherited_proofing/retrieval.html.erb' do
  it 'renders' do
    render template: 'idv/inherited_proofing/retrieval'

    # Appropriate header
    expect(rendered).to have_text(t('inherited_proofing.headings.retrieval'))

    # Spinner
    expect(rendered).to have_css("img[src*='shield-spinner']")

    # Appropriate text
    expect(rendered).to have_text(t('inherited_proofing.info.retrieval_time'))
    expect(rendered).to have_text(t('inherited_proofing.info.retrieval_thanks'))
  end
end
