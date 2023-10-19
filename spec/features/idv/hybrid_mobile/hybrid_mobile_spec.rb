require 'rails_helper'

RSpec.describe 'Hybrid Flow', :allow_net_connect_on_start do
  include IdvHelper
  include IdvStepHelper
  include DocAuthHelper

  let(:phone_number) { '415-555-0199' }
  let(:sp) { :oidc }

  before do
    allow(FeatureManagement).to receive(:doc_capture_polling_enabled?).and_return(true)
  end

  before do
    allow(Telephony).to receive(:send_doc_auth_link).and_wrap_original do |impl, config|
      @sms_link = config[:link]
      impl.call(**config)
    end.at_least(1).times
  end

  it 'proofs and hands off to mobile', js: true do
    user = nil

    perform_in_browser(:desktop) do
      visit_idp_from_sp_with_ial2(sp)
      user = sign_up_and_2fa_ial1_user

      complete_doc_auth_steps_before_hybrid_handoff_step
      clear_and_fill_in(:doc_auth_phone, phone_number)
      click_send_link

      expect(page).to have_content(t('doc_auth.headings.text_message'))
      expect(page).to have_content(t('doc_auth.info.you_entered'))
      expect(page).to have_content('+1 415-555-0199')

      # Confirm that Continue button is not shown when polling is enabled
      expect(page).not_to have_content(t('doc_auth.buttons.continue'))
    end

    expect(@sms_link).to be_present

    perform_in_browser(:mobile) do
      visit @sms_link

      # Confirm that jumping to LinkSent page does not cause errors
      visit idv_link_sent_url
      expect(page).to have_current_path(root_url)
      visit idv_hybrid_mobile_document_capture_url

      # Confirm that jumping to Phone page does not cause errors
      visit idv_phone_url
      expect(page).to have_current_path(root_url)
      visit idv_hybrid_mobile_document_capture_url

      # Confirm that jumping to Welcome page does not cause errors
      # This was added for the GettingStarted A/B Test
      visit idv_welcome_url
      expect(page).to have_current_path(root_url)
      visit idv_hybrid_mobile_document_capture_url

      attach_and_submit_images

      expect(page).to have_current_path(idv_hybrid_mobile_capture_complete_url)
      expect(page).to have_content(t('doc_auth.headings.capture_complete').tr(' ', ' '))
      expect(page).to have_text(t('doc_auth.instructions.switch_back'))
      expect_step_indicator_current_step(t('step_indicator.flows.idv.verify_id'))

      # Confirm app disallows jumping back to DocumentCapture page
      visit idv_hybrid_mobile_document_capture_url
      expect(page).to have_current_path(idv_hybrid_mobile_capture_complete_url)
    end

    perform_in_browser(:desktop) do
      expect(page).to_not have_content(t('doc_auth.headings.text_message'), wait: 10)
      expect(page).to have_current_path(idv_ssn_path)

      fill_out_ssn_form_ok
      click_idv_continue

      expect(page).to have_content(t('headings.verify'))
      click_idv_continue

      prefilled_phone = page.find(id: 'idv_phone_form_phone').value

      expect(
        PhoneFormatter.format(prefilled_phone),
      ).to eq(
        PhoneFormatter.format(user.default_phone_configuration.phone),
      )

      fill_out_phone_form_ok
      verify_phone_otp

      fill_in t('idv.form.password'), with: Features::SessionHelper::VALID_PASSWORD
      click_idv_continue

      acknowledge_and_confirm_personal_key

      validate_idv_completed_page(user)
      click_agree_and_continue

      validate_return_to_sp
    end
  end

  it 'shows the waiting screen correctly after cancelling from mobile and restarting', js: true do
    user = nil

    perform_in_browser(:desktop) do
      user = sign_in_and_2fa_user
      complete_doc_auth_steps_before_hybrid_handoff_step
      clear_and_fill_in(:doc_auth_phone, phone_number)
      click_send_link

      expect(page).to have_content(t('doc_auth.headings.text_message'))
    end

    expect(@sms_link).to be_present

    perform_in_browser(:mobile) do
      visit @sms_link
      click_on t('links.cancel')
      click_on t('forms.buttons.cancel') # Yes, cancel
    end

    perform_in_browser(:desktop) do
      expect(page).to_not have_content(t('doc_auth.headings.text_message'), wait: 10)
      clear_and_fill_in(:doc_auth_phone, phone_number)
      click_send_link

      expect(page).to have_content(t('doc_auth.headings.text_message'))
    end
  end

  context 'user is rate limited on mobile' do
    let(:max_attempts) { IdentityConfig.store.doc_auth_max_attempts }

    before do
      allow(IdentityConfig.store).to receive(:doc_auth_max_attempts).and_return(max_attempts)
      DocAuth::Mock::DocAuthMockClient.mock_response!(
        method: :post_front_image,
        response: DocAuth::Response.new(
          success: false,
          errors: { network: I18n.t('doc_auth.errors.general.network_error') },
        ),
      )
    end

    it 'shows capture complete on mobile and error page on desktop', js: true do
      user = nil

      perform_in_browser(:desktop) do
        user = sign_in_and_2fa_user
        complete_doc_auth_steps_before_hybrid_handoff_step
        clear_and_fill_in(:doc_auth_phone, phone_number)
        click_send_link

        expect(page).to have_content(t('doc_auth.headings.text_message'))
      end

      expect(@sms_link).to be_present

      perform_in_browser(:mobile) do
        visit @sms_link

        (max_attempts - 1).times do
          attach_and_submit_images
          click_on t('idv.failure.button.warning')
        end

        # final failure
        attach_and_submit_images

        expect(page).to have_current_path(idv_hybrid_mobile_capture_complete_url)
        expect(page).not_to have_content(t('doc_auth.headings.capture_complete').tr(' ', ' '))
        expect(page).to have_text(t('doc_auth.instructions.switch_back'))
      end

      perform_in_browser(:desktop) do
        expect(page).to have_current_path(idv_session_errors_rate_limited_path, wait: 10)
      end
    end
  end

  context 'barcode read error on mobile (redo document capture)' do
    it 'continues to ssn on desktop when user selects Continue', js: true do
      user = nil

      perform_in_browser(:desktop) do
        user = sign_in_and_2fa_user
        complete_doc_auth_steps_before_hybrid_handoff_step
        clear_and_fill_in(:doc_auth_phone, phone_number)
        click_send_link

        expect(page).to have_content(t('doc_auth.headings.text_message'))
      end

      expect(@sms_link).to be_present

      perform_in_browser(:mobile) do
        visit @sms_link

        mock_doc_auth_attention_with_barcode
        attach_and_submit_images
        click_idv_continue

        expect(page).to have_current_path(idv_hybrid_mobile_capture_complete_url)
        expect(page).to have_content(t('doc_auth.headings.capture_complete').tr(' ', ' '))
        expect(page).to have_text(t('doc_auth.instructions.switch_back'))
      end

      perform_in_browser(:desktop) do
        expect(page).to have_current_path(idv_ssn_path, wait: 10)

        fill_out_ssn_form_ok
        click_idv_continue

        expect(page).to have_current_path(idv_verify_info_path, wait: 10)

        # verify pii is displayed
        expect(page).to have_text('DAVID')
        expect(page).to have_text('SAMPLE')
        expect(page).to have_text('123 ABC AVE')

        warning_link_text = t('doc_auth.headings.capture_scan_warning_link')
        click_link warning_link_text

        expect(current_path).to eq(idv_hybrid_handoff_path)
        clear_and_fill_in(:doc_auth_phone, phone_number)
        click_send_link
      end

      perform_in_browser(:mobile) do
        visit @sms_link

        DocAuth::Mock::DocAuthMockClient.reset!
        attach_and_submit_images

        expect(page).to have_current_path(idv_hybrid_mobile_capture_complete_url)
      end

      perform_in_browser(:desktop) do
        expect(page).to have_current_path(idv_verify_info_path, wait: 10)

        # verify orig pii no longer displayed
        expect(page).not_to have_text('DAVID')
        expect(page).not_to have_text('SAMPLE')
        expect(page).not_to have_text('123 ABC AVE')
        # verify new pii from redo is displayed
        expect(page).to have_text(Idp::Constants::MOCK_IDV_APPLICANT[:first_name])
        expect(page).to have_text(Idp::Constants::MOCK_IDV_APPLICANT[:last_name])
        expect(page).to have_text(Idp::Constants::MOCK_IDV_APPLICANT[:address1])

        click_idv_continue
      end
    end
  end

  context 'barcode read error on desktop, redo document capture on mobile' do
    it 'continues to ssn on desktop when user selects Continue', js: true do
      user = nil

      perform_in_browser(:desktop) do
        user = sign_in_and_2fa_user
        complete_doc_auth_steps_before_document_capture_step
        mock_doc_auth_attention_with_barcode
        attach_and_submit_images
        click_idv_continue
        expect(page).to have_current_path(idv_ssn_path, wait: 10)

        fill_out_ssn_form_ok
        click_idv_continue

        expect(page).to have_current_path(idv_verify_info_path, wait: 10)

        # verify pii is displayed
        expect(page).to have_text('DAVID')
        expect(page).to have_text('SAMPLE')
        expect(page).to have_text('123 ABC AVE')

        warning_link_text = t('doc_auth.headings.capture_scan_warning_link')
        click_link warning_link_text

        expect(current_path).to eq(idv_hybrid_handoff_path)
        clear_and_fill_in(:doc_auth_phone, phone_number)
        click_send_link
      end

      perform_in_browser(:mobile) do
        visit @sms_link

        DocAuth::Mock::DocAuthMockClient.reset!
        attach_and_submit_images

        expect(page).to have_current_path(idv_hybrid_mobile_capture_complete_url)
      end

      perform_in_browser(:desktop) do
        expect(page).to have_current_path(idv_verify_info_path, wait: 10)

        # verify orig pii no longer displayed
        expect(page).not_to have_text('DAVID')
        expect(page).not_to have_text('SAMPLE')
        expect(page).not_to have_text('123 ABC AVE')
        # verify new pii from redo is displayed
        expect(page).to have_text(Idp::Constants::MOCK_IDV_APPLICANT[:first_name])
        expect(page).to have_text(Idp::Constants::MOCK_IDV_APPLICANT[:last_name])
        expect(page).to have_text(Idp::Constants::MOCK_IDV_APPLICANT[:address1])

        click_idv_continue
      end
    end
  end

  it 'prefils the phone number used on the phone step if the user has no MFA phone', :js do
    user = create(:user, :with_authentication_app)

    perform_in_browser(:desktop) do
      start_idv_from_sp
      sign_in_and_2fa_user(user)

      complete_doc_auth_steps_before_hybrid_handoff_step
      clear_and_fill_in(:doc_auth_phone, phone_number)
      click_send_link
    end

    expect(@sms_link).to be_present

    perform_in_browser(:mobile) do
      visit @sms_link
      attach_and_submit_images

      expect(page).to have_current_path(idv_hybrid_mobile_capture_complete_url)
      expect(page).to have_text(t('doc_auth.instructions.switch_back'))
    end

    perform_in_browser(:desktop) do
      expect(page).to have_current_path(idv_ssn_path, wait: 10)

      fill_out_ssn_form_ok
      click_idv_continue

      expect(page).to have_content(t('headings.verify'))
      click_idv_continue

      prefilled_phone = page.find(id: 'idv_phone_form_phone').value

      expect(
        PhoneFormatter.format(prefilled_phone),
      ).to eq(
        PhoneFormatter.format(phone_number),
      )
    end
  end
end
