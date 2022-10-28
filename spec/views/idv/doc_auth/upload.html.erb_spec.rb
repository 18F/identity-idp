require 'rails_helper'

describe 'idv/doc_auth/upload.html.erb' do
  let(:flow_session) { {} }
  let(:user_fully_authenticated) { true }

  before do
    allow(view).to receive(:flow_session).and_return(flow_session)
    allow(view).to receive(:user_fully_authenticated?).and_return(user_fully_authenticated)
    allow(view).to receive(:url_for).and_return('https://www.example.com/')
    allow(view).to receive(:user_signing_up?).and_return(false)
  end

  context 'with liveness disabled' do
    it 'does not render liveness content' do
      render template: 'idv/doc_auth/upload'

      expect(rendered).to have_content(t('doc_auth.headings.upload'))
      expect(rendered).to have_content(t('doc_auth.info.upload'))
      expect(rendered).to have_content(t('doc_auth.headings.upload_from_phone'))
    end
  end
end
