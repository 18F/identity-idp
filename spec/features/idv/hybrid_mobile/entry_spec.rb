require 'rails_helper'

feature 'mobile hybrid flow entry', js: true do
  include IdvStepHelper

  before do
    allow(IdentityConfig.store).to receive(:doc_auth_hybrid_mobile_controllers_enabled).
      and_return(true)
  end

  let(:link_sent_via_sms) do
    link = nil

    # Intercept the link being SMS'd to the user.
    allow(Telephony).to receive(:send_doc_auth_link).and_wrap_original do |impl, config|
      link = config[:link]
      impl.call(**config)
    end

    sign_in_and_2fa_user
    complete_doc_auth_steps_before_upload_step
    click_send_link

    link
  end

  let(:link_to_visit) { link_sent_via_sms }

  context 'valid link' do
    it 'puts the user on the document capture page' do
      expect(link_to_visit).to be

      Capybara.using_session('mobile') do
        visit link_to_visit
        # Should have redirected to the actual doc capture url
        expect(current_url).to eql(idv_hybrid_mobile_document_capture_url)
      end
    end
  end

  context 'invalid link' do
    let(:link_to_visit) do
      # Put an invalid document-capture-session in the URL
      uri = URI.parse(link_sent_via_sms)
      query = Rack::Utils.parse_query(uri.query)
      query['document-capture-session'] = SecureRandom.uuid
      uri.query = Rack::Utils.build_query(query)
      uri.to_s
    end

    it 'redirects to the root' do
      expect(link_to_visit).to be

      Capybara.using_session('mobile') do
        visit link_to_visit
        expect(current_url).to eql(root_url)
      end
    end
  end
end
