require 'rails_helper'

describe 'idv/inherited_proofing/agreement.html.erb' do
  let(:flow_session) { {} }
  let(:sp_name) { nil }
  let(:locale) { nil }

  before do
    allow(view).to receive(:decorated_session).and_return(@decorated_session)
    allow(view).to receive(:flow_session).and_return(flow_session)
    allow(view).to receive(:url_for).and_return('https://www.example.com/')
  end

  it 'renders the Continue button' do
    render template: 'idv/inherited_proofing/agreement'

    expect(rendered).to have_button(t('inherited_proofing.buttons.continue'))
  end

  context 'with or without service provider' do
    it 'renders content' do
      render template: 'idv/inherited_proofing/agreement'

      expect(rendered).to have_content(t('inherited_proofing.info.lets_go'))
      expect(rendered).to have_content(
        t('inherited_proofing.headings.verify_identity'),
      )
      expect(rendered).to have_content(t('inherited_proofing.info.verify_identity'))
      expect(rendered).to have_content(
        t('inherited_proofing.headings.secure_account'),
      )
      expect(rendered).to have_content(
        t('inherited_proofing.info.secure_account', sp_name: sp_name),
      )
    end
  end
end
