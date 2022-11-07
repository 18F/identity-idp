require 'rails_helper'
require 'axe-rspec'

RSpec.describe 'In Person Proofing', js: true do
  include IdvStepHelper
  include SpAuthHelper
  include InPersonHelper

  before do
    allow(IdentityConfig.store).to receive(:in_person_proofing_enabled).and_return(true)
  end

  it 'works for a happy path', allow_browser_log: true do
    user = user_with_2fa

    sign_in_and_2fa_user(user)
    begin_in_person_proofing(user)

    # location page
    expect_in_person_step_indicator_current_step(t('step_indicator.flows.idv.find_a_post_office'))
    expect(page).to have_content(t('in_person_proofing.headings.location'))
    bethesda_location = page.find_all('.location-collection-item')[1]
    bethesda_location.click_button(t('in_person_proofing.body.location.location_button'))

    # prepare page
    expect_in_person_step_indicator_current_step(t('step_indicator.flows.idv.find_a_post_office'))
    expect(page).to have_content(t('in_person_proofing.headings.prepare'))
    complete_prepare_step(user)

    # state ID page
    expect_in_person_step_indicator_current_step(t('step_indicator.flows.idv.verify_info'))
    expect(page).to have_content(t('in_person_proofing.headings.state_id'))
    complete_state_id_step(user)

    # address page
    expect_in_person_step_indicator_current_step(t('step_indicator.flows.idv.verify_info'))
    expect(page).to have_content(t('in_person_proofing.headings.address'))
    complete_address_step(user)

    # ssn page
    expect_in_person_step_indicator_current_step(t('step_indicator.flows.idv.verify_info'))
    expect(page).to have_content(t('doc_auth.headings.ssn'))
    complete_ssn_step(user)

    # verify page
    expect_in_person_step_indicator_current_step(t('step_indicator.flows.idv.verify_info'))
    expect(page).to have_content(t('headings.verify'))
    expect(page).to have_text(InPersonHelper::GOOD_FIRST_NAME)
    expect(page).to have_text(InPersonHelper::GOOD_LAST_NAME)
    expect(page).to have_text(InPersonHelper::GOOD_DOB)
    expect(page).to have_text(InPersonHelper::GOOD_STATE_ID_NUMBER)
    expect(page).to have_text(InPersonHelper::GOOD_ADDRESS1)
    expect(page).to have_text(InPersonHelper::GOOD_CITY)
    expect(page).to have_text(InPersonHelper::GOOD_ZIPCODE)
    expect(page).to have_text(Idp::Constants::MOCK_IDV_APPLICANT[:state])
    expect(page).to have_text('9**-**-***4')

    # click update state ID button
    click_button t('idv.buttons.change_state_id_label')
    expect(page).to have_content(t('in_person_proofing.headings.update_state_id'))
    click_button t('forms.buttons.submit.update')
    expect(page).to have_content(t('headings.verify'))

    # click update address button
    click_button t('idv.buttons.change_address_label')
    expect(page).to have_content(t('in_person_proofing.headings.update_address'))
    click_button t('forms.buttons.submit.update')
    expect(page).to have_content(t('headings.verify'))

    # click update ssn button
    click_button t('idv.buttons.change_ssn_label')
    expect(page).to have_content(t('doc_auth.headings.ssn_update'))
    fill_out_ssn_form_ok
    click_button t('forms.buttons.submit.update')
    expect(page).to have_content(t('headings.verify'))
    complete_verify_step(user)

    # phone page
    expect_in_person_step_indicator_current_step(
      t('step_indicator.flows.idv.verify_phone_or_address'),
    )
    expect(page).to have_content(t('idv.titles.session.phone'))
    fill_out_phone_form_ok(MfaContext.new(user).phone_configurations.first.phone)
    click_idv_continue
    expect_in_person_step_indicator_current_step(
      t('step_indicator.flows.idv.verify_phone_or_address'),
    )
    choose_idv_otp_delivery_method_sms
    expect_in_person_step_indicator_current_step(
      t('step_indicator.flows.idv.verify_phone_or_address'),
    )
    fill_in_code_with_last_phone_otp
    click_submit_default

    # password confirm page
    expect_in_person_step_indicator_current_step(t('step_indicator.flows.idv.secure_account'))
    expect(page).to have_content(t('idv.titles.session.review', app_name: APP_NAME))
    complete_review_step(user)

    # personal key page
    expect_in_person_step_indicator_current_step(t('step_indicator.flows.idv.secure_account'))
    expect(page).to have_content(t('titles.idv.personal_key'))
    deadline = nil
    freeze_time do
      acknowledge_and_confirm_personal_key
      deadline = (Time.zone.now + IdentityConfig.store.in_person_enrollment_validity_in_days.days).
        in_time_zone(Idv::InPerson::ReadyToVerifyPresenter::USPS_SERVER_TIMEZONE).
        strftime(t('time.formats.event_date'))
    end

    # ready to verify page
    expect_in_person_step_indicator_current_step(
      t('step_indicator.flows.idv.go_to_the_post_office'),
    )
    expect(page).to be_axe_clean.according_to :section508, :"best-practice", :wcag21aa
    enrollment_code = JSON.parse(
      UspsInPersonProofing::Mock::Fixtures.request_enroll_response,
    )['enrollmentCode']
    expect(page).to have_content(t('in_person_proofing.headings.barcode'))
    expect(page).to have_content(Idv::InPerson::EnrollmentCodeFormatter.format(enrollment_code))
    expect(page).to have_content(t('in_person_proofing.body.barcode.deadline', deadline: deadline))
    expect(page).to have_content('BETHESDA')
    expect(page).to have_content(
      "#{t('date.day_names')[6]}: #{t('in_person_proofing.body.barcode.retail_hours_closed')}",
    )

    # signing in again before completing in-person proofing at a post office
    sign_in_and_2fa_user(user)
    complete_doc_auth_steps_before_welcome_step
    expect(page).to have_current_path(idv_in_person_ready_to_verify_path)
  end

  it 'allows the user to cancel and start over from the beginning', allow_browser_log: true do
    sign_in_and_2fa_user
    begin_in_person_proofing
    complete_all_in_person_proofing_steps

    click_link t('links.cancel')
    click_on t('idv.cancel.actions.start_over')

    expect(page).to have_current_path(idv_doc_auth_welcome_step)
    begin_in_person_proofing
    complete_all_in_person_proofing_steps
  end

  it 'allows the user to go back to document capture from prepare step', allow_browser_log: true do
    sign_in_and_2fa_user
    begin_in_person_proofing

    # location page
    expect(page).to have_content(t('in_person_proofing.headings.location'))
    bethesda_location = page.find_all('.location-collection-item')[1]
    bethesda_location.click_button(t('in_person_proofing.body.location.location_button'))

    # prepare page
    expect(page).to have_content(t('in_person_proofing.headings.prepare'))
    click_button t('forms.buttons.back')

    expect(page).to have_content(t('in_person_proofing.headings.location'))
    expect(page).to have_css('.location-collection-item', wait: 10)
    click_button t('forms.buttons.back')

    # Note: This is specifically for failed barcodes. Other cases may use
    #      "idv.failure.button.warning" instead.
    expect(page).to have_button(t('doc_auth.buttons.add_new_photos'))
    click_button t('doc_auth.buttons.add_new_photos')

    expect(page).to have_content(t('doc_auth.headings.review_issues'))

    # Images should still be present
    front_label = [t('doc_auth.headings.document_capture_front'), 'logo.png'].join(' - ')
    back_label = [t('doc_auth.headings.document_capture_back'), 'logo.png'].join(' - ')
    expect(page).to have_field(front_label)
    expect(page).to have_field(back_label)
  end

  context 'after in-person proofing is completed and passed for a partner' do
    let(:sp) { nil }
    before do
      create_in_person_ial2_account_go_back_to_sp_and_sign_out(sp)
    end

    [
      :oidc,
      :saml,
    ].each do |service_provider|
      context "using #{service_provider}" do
        let(:sp) { service_provider }
        it 'sends a survey when they share information with that partner',
           allow_browser_log: true do
          expect(last_email.html_part.body).
            to have_selector(
              "a[href='#{IdentityConfig.store.in_person_completion_survey_url}']",
            )
        end
      end
    end
  end

  context 'with hybrid document capture' do
    before do
      allow(FeatureManagement).to receive(:doc_capture_polling_enabled?).and_return(true)
      allow(Telephony).to receive(:send_doc_auth_link).and_wrap_original do |impl, config|
        @sms_link = config[:link]
        impl.call(**config)
      end
    end

    it 'resumes desktop session with in-person proofing', allow_browser_log: true do
      user = nil

      perform_in_browser(:desktop) do
        user = sign_in_and_2fa_user
        complete_doc_auth_steps_before_send_link_step
        fill_in :doc_auth_phone, with: '415-555-0199'
        click_idv_continue
      end

      perform_in_browser(:mobile) do
        visit @sms_link
        mock_doc_auth_attention_with_barcode
        attach_and_submit_images

        click_link t('in_person_proofing.body.cta.button')

        bethesda_location = page.find_all('.location-collection-item')[1]
        bethesda_location.click_button(t('in_person_proofing.body.location.location_button'))

        click_idv_continue

        expect(page).to have_content(t('in_person_proofing.headings.switch_back'))
      end

      perform_in_browser(:desktop) do
        expect(page).to have_current_path(idv_in_person_step_path(step: :state_id), wait: 10)

        complete_state_id_step(user)
        complete_address_step(user)
        complete_ssn_step(user)
        complete_verify_step(user)
        complete_phone_step(user)
        complete_review_step(user)
        acknowledge_and_confirm_personal_key

        expect(page).to have_content('BETHESDA')
      end
    end
  end

  context 'verify address by mail (GPO letter)' do
    before do
      allow(FeatureManagement).to receive(:reveal_gpo_code?).and_return(true)
    end

    it 'requires address verification before showing instructions', allow_browser_log: true do
      sign_in_and_2fa_user
      begin_in_person_proofing
      complete_all_in_person_proofing_steps
      click_on t('idv.troubleshooting.options.verify_by_mail')
      expect_in_person_step_indicator_current_step(
        t('step_indicator.flows.idv.verify_phone_or_address'),
      )
      click_on t('idv.buttons.mail.send')
      expect_in_person_gpo_step_indicator_current_step(t('step_indicator.flows.idv.secure_account'))
      complete_review_step
      expect_in_person_gpo_step_indicator_current_step(t('step_indicator.flows.idv.secure_account'))
      acknowledge_and_confirm_personal_key

      expect_in_person_gpo_step_indicator_current_step(t('step_indicator.flows.idv.get_a_letter'))
      expect(page).to have_content(t('idv.titles.come_back_later'))
      expect(page).to have_current_path(idv_come_back_later_path)

      click_idv_continue
      expect(page).to have_current_path(account_path)
      expect(page).not_to have_content(t('headings.account.verified_account'))
      click_on t('account.index.verification.reactivate_button')
      expect_in_person_gpo_step_indicator_current_step(t('step_indicator.flows.idv.get_a_letter'))
      click_button t('forms.verify_profile.submit')

      expect(page).to have_current_path(idv_in_person_ready_to_verify_path)
      expect_in_person_gpo_step_indicator_current_step(
        t('step_indicator.flows.idv.go_to_the_post_office'),
      )
      expect(page).not_to have_content(t('account.index.verification.success'))
    end

    it 'lets the user clear and start over from gpo confirmation', allow_browser_log: true do
      sign_in_and_2fa_user
      begin_in_person_proofing
      complete_all_in_person_proofing_steps
      click_on t('idv.troubleshooting.options.verify_by_mail')
      click_on t('idv.buttons.mail.send')
      complete_review_step
      acknowledge_and_confirm_personal_key
      click_idv_continue
      click_on t('account.index.verification.reactivate_button')
      click_on t('idv.messages.clear_and_start_over')

      expect(page).to have_current_path(idv_doc_auth_welcome_step)
    end
  end
end
