require 'rails_helper'

describe 'idv/inherited_proofing/retrieval.html.erb' do
  let(:flow_session) { {} }
  let(:sp_name) { nil }
  let(:locale) { nil }

  before do
    allow(view).to receive(:decorated_session).and_return(@decorated_session)
    allow(view).to receive(:flow_session).and_return(flow_session)
    allow(view).to receive(:url_for).and_return('https://www.example.com/')
  end

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
