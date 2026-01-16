require 'rails_helper'

RSpec.feature 'mobile hybrid flow entry', :js do
  include IdvStepHelper

  let(:link_sent_via_sms) do
    link = nil

    # Intercept the link being SMS'd to the user.
    allow(Telephony).to receive(:send_doc_auth_link).and_wrap_original do |impl, config|
      link = config[:link]
      impl.call(**config)
    end

    sign_in_and_2fa_user
    complete_doc_auth_steps_before_hybrid_handoff_step
    click_send_link

    expect(page).to have_content(t('doc_auth.headings.text_message'))

    link
  end

  let(:link_to_visit) { link_sent_via_sms }

  before do
    reload_ab_tests
  end

  context 'valid link' do
    before do
      allow(IdentityConfig.store).to receive(:socure_docv_enabled).and_return(true)
    end

    it 'puts the user on the document capture page' do
      expect(link_to_visit).to be

      Capybara.using_session('mobile') do
        visit link_to_visit
        complete_choose_id_type_step
        expect(page).to have_current_path(idv_hybrid_mobile_document_capture_path)

        # Confirm that we end up on the LN / Mock page even if we try to
        # go to the Socure one.
        visit idv_hybrid_mobile_socure_document_capture_url
        expect(page).to have_current_path(idv_hybrid_mobile_document_capture_path)
      end
    end

    context 'when socure is the doc auth vendor' do
      before do
        allow(IdentityConfig.store).to receive_messages(
          doc_auth_vendor_lexis_nexis_percent: 0,
          doc_auth_vendor_socure_percent: 100,
          doc_auth_vendor_switching_enabled: true,
        )
        stub_docv_document_request
        reload_ab_tests
      end

      it 'puts the user on the socure document capture page' do
        expect(link_to_visit).to be

        Capybara.using_session('mobile') do
          visit link_to_visit
          complete_choose_id_type_step
          expect(page).to have_current_path(idv_hybrid_mobile_socure_document_capture_path)

          # Confirm that we end up on the LN / Mock page even if we try to
          # go to the Socure one.
          visit idv_hybrid_mobile_document_capture_url
          expect(page).to have_current_path(idv_hybrid_mobile_socure_document_capture_path)
        end
      end
    end
  end

  context 'old link' do
    let(:link_to_visit) do
      # Edit in the old link, which should redirect to the new controller
      uri = URI.parse(link_sent_via_sms)
      uri.path = '/verify/capture-doc'
      uri.to_s
    end

    it 'puts the user on the new document capture page' do
      expect(link_to_visit).to be

      Capybara.using_session('mobile') do
        visit link_to_visit
        complete_choose_id_type_step
        expect(page).to have_current_path(idv_hybrid_mobile_document_capture_path)
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
        expect(page).to have_current_path(root_path)
      end
    end
  end
end
