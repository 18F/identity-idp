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

  context 'with liveness enabled' do
    it 'renders liveness content' do
      allow(view).to receive(:liveness_checking_enabled?).and_return(true)
      render template: 'idv/doc_auth/upload.html.erb'

      expect(rendered).to include(CGI.escapeHTML(t('doc_auth.headings.upload_liveness_enabled')))
      expect(rendered).to include(CGI.escapeHTML(t('doc_auth.info.upload_liveness_enabled')))
      expect(rendered).to include(
        CGI.escapeHTML(t('doc_auth.headings.upload_from_phone_liveness_enabled')),
      )
    end
  end

  context 'with liveness disabled' do
    it 'does not render liveness content' do
      allow(view).to receive(:liveness_checking_enabled?).and_return(false)
      render template: 'idv/doc_auth/upload.html.erb'

      expect(rendered).to include(CGI.escapeHTML(t('doc_auth.headings.upload')))
      expect(rendered).to include(CGI.escapeHTML(t('doc_auth.info.upload')))
      expect(rendered).to include(CGI.escapeHTML(t('doc_auth.headings.upload_from_phone')))
    end
  end
end
