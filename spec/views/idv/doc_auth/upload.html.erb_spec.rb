require 'rails_helper'

describe 'idv/doc_auth/upload.html.erb' do
  let(:flow_session) { {} }
  let(:user_fully_authenticated) { true }
  let(:sp_name) { nil }
  let(:failure_to_proof_url) { 'https://example.com' }

  before do
    @decorated_session = instance_double(ServiceProviderSessionDecorator)
    allow(@decorated_session).to receive(:sp_name).and_return(sp_name)
    allow(@decorated_session).to receive(:failure_to_proof_url).and_return(failure_to_proof_url)
    allow(view).to receive(:decorated_session).and_return(@decorated_session)
    allow(view).to receive(:flow_session).and_return(flow_session)
    allow(view).to receive(:user_fully_authenticated?).and_return(user_fully_authenticated)
    allow(view).to receive(:url_for).and_return('https://www.example.com/')
    allow(view).to receive(:user_signing_up?).and_return(false)
  end

  context 'with liveness enabled' do
    it 'renders liveness content' do
      allow(view).to receive(:liveness_checking_enabled?).and_return(true)
      render template: 'idv/doc_auth/upload.html.erb'

      expect(rendered).to have_content(t('doc_auth.headings.upload_liveness_enabled'))
      expect(rendered).to have_content(t('doc_auth.info.upload_liveness_enabled'))
      expect(rendered).to have_content(t('doc_auth.headings.upload_from_phone_liveness_enabled'))
    end
  end

  context 'with liveness disabled' do
    it 'does not render liveness content' do
      allow(view).to receive(:liveness_checking_enabled?).and_return(false)
      render template: 'idv/doc_auth/upload.html.erb'

      expect(rendered).to have_content(t('doc_auth.headings.upload'))
      expect(rendered).to have_content(t('doc_auth.info.upload'))
      expect(rendered).to have_content(t('doc_auth.headings.upload_from_phone'))
    end
  end

  context 'without service provider' do
    it 'does not render fallback support link' do
      render template: 'idv/doc_auth/upload.html.erb'

      link_text = t(
        'doc_auth.info.no_other_id_help_bold_html',
        failure_to_proof_url: @decorated_session.failure_to_proof_url,
        sp_name: @decorated_session.sp_name,
      )

      expect(rendered).not_to include(link_text)
    end
  end

  context 'with service provider' do
    let(:sp_name) { 'Example App' }

    it 'renders fallback support link' do
      render template: 'idv/doc_auth/upload.html.erb'

      link_text = t(
        'doc_auth.info.no_other_id_help_bold_html',
        failure_to_proof_url: @decorated_session.failure_to_proof_url,
        sp_name: @decorated_session.sp_name,
      )
      expect(rendered).to include(link_text)
    end
  end
end
