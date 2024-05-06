require 'rails_helper'
require 'axe-rspec'

RSpec.describe 'In Person Proofing', js: true, allowed_extra_analytics: [:*] do
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

    # prepare page
    expect(page).to(have_content(t('in_person_proofing.body.prepare.verify_step_about')))
    expect_in_person_step_indicator_current_step(t('step_indicator.flows.idv.find_a_post_office'))
    complete_prepare_step(user)

    # location page
    expect_in_person_step_indicator_current_step(t('step_indicator.flows.idv.find_a_post_office'))
    expect(page).to have_content(t('in_person_proofing.headings.po_search.location'))
    complete_location_step

    # state ID page
    expect_in_person_step_indicator_current_step(
      t('step_indicator.flows.idv.verify_info'),
    )
    expect(page).to have_content(
      t(
        'in_person_proofing.headings.state_id_milestone_2',
      ).tr(' ', ' '),
    )
    complete_state_id_step(user)

    # ssn page
    expect_in_person_step_indicator_current_step(t('step_indicator.flows.idv.verify_info'))
    expect(page).to have_content(t('doc_auth.headings.ssn'))
    complete_ssn_step(user)

    # verify page
    expect_in_person_step_indicator_current_step(t('step_indicator.flows.idv.verify_info'))
    expect(page).to have_content(t('headings.verify'))
    expect(page).to have_current_path(idv_in_person_verify_info_path)
    expect(page).to have_text(InPersonHelper::GOOD_FIRST_NAME)
    expect(page).to have_text(InPersonHelper::GOOD_LAST_NAME)
    expect(page).to have_text(InPersonHelper::GOOD_DOB_FORMATTED_EVENT)
    expect(page).to have_text(InPersonHelper::GOOD_STATE_ID_NUMBER)
    expect(page).to have_text(InPersonHelper::GOOD_IDENTITY_DOC_ADDRESS1).twice
    expect(page).to have_text(InPersonHelper::GOOD_IDENTITY_DOC_ADDRESS2).twice
    expect(page).to have_text(InPersonHelper::GOOD_IDENTITY_DOC_CITY).twice
    expect(page).to have_text(Idp::Constants::MOCK_IDV_APPLICANT[:state_id_jurisdiction], count: 3)
    expect(page).to have_text(InPersonHelper::GOOD_IDENTITY_DOC_ZIPCODE).twice
    expect(page).to have_text(DocAuthHelper::GOOD_SSN_MASKED)

    # click update state ID button
    click_button t('idv.buttons.change_state_id_label')
    expect(page).to have_content(t('in_person_proofing.headings.update_state_id'))
    choose t('in_person_proofing.form.state_id.same_address_as_id_yes')
    click_button t('forms.buttons.submit.update')
    expect(page).to have_content(t('headings.verify'))
    expect(page).to have_current_path(idv_in_person_verify_info_path)

    # click update address link
    click_link t('idv.buttons.change_address_label')
    expect(page).to have_content(t('in_person_proofing.headings.update_address'))
    click_button t('forms.buttons.submit.update')
    expect(page).to have_content(t('headings.verify'))
    expect(page).to have_current_path(idv_in_person_verify_info_path)

    # click update ssn button
    click_on t('idv.buttons.change_ssn_label')
    expect(page).to have_content(t('doc_auth.headings.ssn_update'))
    fill_out_ssn_form_ok
    click_button t('forms.buttons.submit.update')
    expect(page).to have_content(t('headings.verify'))
    expect(page).to have_current_path(idv_in_person_verify_info_path)
    complete_verify_step(user)

    # phone page
    expect_in_person_step_indicator_current_step(
      t('step_indicator.flows.idv.verify_phone_or_address'),
    )
    expect(page).to have_content(t('titles.idv.phone'))
    fill_out_phone_form_ok(MfaContext.new(user).phone_configurations.first.phone)
    click_idv_send_security_code
    expect_in_person_step_indicator_current_step(
      t('step_indicator.flows.idv.verify_phone_or_address'),
    )

    expect_in_person_step_indicator_current_step(
      t('step_indicator.flows.idv.verify_phone_or_address'),
    )
    fill_in_code_with_last_phone_otp
    click_submit_default

    # password confirm page
    expect_in_person_step_indicator_current_step(t('step_indicator.flows.idv.secure_account'))
    expect(page).to have_content(t('idv.titles.session.enter_password', app_name: APP_NAME))
    complete_enter_password_step(user)

    # personal key page
    expect_in_person_step_indicator
    expect(page).not_to have_css('.step-indicator__step--current')
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
    expect_page_to_have_no_accessibility_violations(page)
    enrollment_code = JSON.parse(
      UspsInPersonProofing::Mock::Fixtures.request_enroll_response,
    )['enrollmentCode']
    expect(page).to have_css("img[alt='#{APP_NAME}']")
    expect(page).to have_content(t('in_person_proofing.headings.barcode').tr(' ', ' '))
    expect(page).to have_content(Idv::InPerson::EnrollmentCodeFormatter.format(enrollment_code))
    expect(page).to have_content(t('in_person_proofing.body.barcode.deadline', deadline: deadline))
    expect(page).to have_content('MILWAUKEE')
    expect(page).to have_content('Sunday: Closed')

    # signing in again before completing in-person proofing at a post office
    Capybara.reset_session!
    sign_in_live_with_2fa(user)
    visit_idp_from_sp_with_ial2(:oidc)
    expect(page).to have_current_path(idv_in_person_ready_to_verify_path)

    # confirm that user cannot visit other IdV pages before completing in-person proofing
    visit idv_agreement_path
    expect(page).to have_current_path(idv_in_person_ready_to_verify_path)
    visit idv_ssn_url
    expect(page).to have_current_path(idv_in_person_ready_to_verify_path)
    visit idv_verify_info_url
    expect(page).to have_current_path(idv_in_person_ready_to_verify_path)

    # Confirms that user can visit account page even if not completing in person proofing
    Capybara.reset_session!
    sign_in_and_2fa_user(user)
    expect(page).to have_current_path(account_path)
  end

  it 'allows the user to cancel and start over from the beginning', allow_browser_log: true do
    user = sign_in_and_2fa_user
    begin_in_person_proofing
    complete_all_in_person_proofing_steps
    complete_phone_step(user)
    complete_enter_password_step(user)
    acknowledge_and_confirm_personal_key

    click_link t('links.cancel')
    click_on t('idv.cancel.actions.start_over')

    expect(page).to have_current_path(idv_welcome_path)
    begin_in_person_proofing
    complete_all_in_person_proofing_steps
  end

  it 'allows the user to go back to document capture from location step', allow_browser_log: true do
    sign_in_and_2fa_user
    begin_in_person_proofing
    complete_prepare_step
    search_for_post_office
    expect(page).to have_css('.location-collection-item', wait: 10)
    # back to prepare page
    click_button t('forms.buttons.back')
    expect(page).to have_content(t('in_person_proofing.headings.prepare'))

    # back to doc capture page
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

    it 'resumes desktop session with in-person proofing when same_address_as_id is true',
       allow_browser_log: true do
      user = nil

      perform_in_browser(:desktop) do
        user = sign_in_and_2fa_user
        complete_doc_auth_steps_before_hybrid_handoff_step
        clear_and_fill_in(:doc_auth_phone, '415-555-0199')
        click_send_link

        expect(page).to have_content(t('doc_auth.headings.text_message'))
      end

      expect(@sms_link).to be_present

      perform_mobile_hybrid_steps
      perform_desktop_hybrid_steps(user)
    end

    it 'resumes desktop session with in-person proofing when same_address_as_id is false',
       allow_browser_log: true do
      user = nil

      perform_in_browser(:desktop) do
        user = sign_in_and_2fa_user
        complete_doc_auth_steps_before_hybrid_handoff_step
        clear_and_fill_in(:doc_auth_phone, '415-555-0199')
        click_send_link

        expect(page).to have_content(t('doc_auth.headings.text_message'))
      end

      expect(@sms_link).to be_present

      perform_mobile_hybrid_steps
      perform_desktop_hybrid_steps(user, same_address_as_id: false)
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
      expect_in_person_gpo_step_indicator_current_step(t('step_indicator.flows.idv.get_a_letter'))
      complete_enter_password_step

      expect_in_person_gpo_step_indicator_current_step(t('step_indicator.flows.idv.get_a_letter'))
      expect(page).to have_content(t('idv.titles.come_back_later'))
      expect(page).to have_current_path(idv_letter_enqueued_path)

      click_idv_continue
      expect(page).to have_current_path(account_path)
      expect(page).not_to have_content(t('headings.account.verified_account'))
      click_on t('account.index.verification.reactivate_button')
      expect_in_person_gpo_step_indicator_current_step(t('step_indicator.flows.idv.get_a_letter'))
      click_button t('idv.gpo.form.submit')

      # personal key
      expect_in_person_step_indicator
      expect(page).not_to have_css('.step-indicator__step--current')
      expect(page).to have_content(t('titles.idv.personal_key'))
      acknowledge_and_confirm_personal_key

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
      complete_enter_password_step
      click_idv_continue
      click_on t('account.index.verification.reactivate_button')
      click_on t('idv.gpo.address_accordion.title')
      click_on t('idv.gpo.address_accordion.cta_link')
      click_idv_continue

      expect(page).to have_current_path(idv_welcome_path)
    end
  end

  context 'same address as id is false',
          allow_browser_log: true do
    let(:user) { user_with_2fa }

    before(:each) do
      sign_in_and_2fa_user(user)
      begin_in_person_proofing(user)
      complete_prepare_step(user)
      complete_location_step(user)
    end

    it 'shows the address page' do
      complete_state_id_step(user, same_address_as_id: false)
      expect_in_person_step_indicator_current_step(t('step_indicator.flows.idv.verify_info'))
      expect(page).to have_content(t('in_person_proofing.headings.address'))

      # arrive at address step
      complete_address_step(user, same_address_as_id: false)
      complete_ssn_step(user)

      # Ensure the page submitted successfully
      expect(page).to have_content(t('idv.form.ssn_label'))
    end

    it 'can update the address page form' do
      complete_state_id_step(user, same_address_as_id: false)
      complete_address_step(user, same_address_as_id: false)
      complete_ssn_step(user)
      # click update address link on the verify page
      click_link t('idv.buttons.change_address_label')
      expect(page).to have_content(t('in_person_proofing.headings.update_address'))
      fill_out_address_form_ok(same_address_as_id: true)
      click_button t('forms.buttons.submit.update')
      expect(page).to have_content(t('headings.verify'))
      expect(page).to have_current_path(idv_in_person_verify_info_path)
    end
  end

  context 'same address as id is true',
          allow_browser_log: true do
    let(:user) { user_with_2fa }

    before(:each) do
      sign_in_and_2fa_user(user)
      begin_in_person_proofing(user)
      complete_prepare_step(user)
      complete_location_step(user)
    end

    it 'allows user to update their residential address as different from their state id' do
      complete_state_id_step(user, same_address_as_id: true)
      # skip address step b/c residential address is same as state id address
      complete_ssn_step(user)

      # click "update residential address"
      click_link t('idv.buttons.change_address_label')
      expect(page).to have_content(t('in_person_proofing.headings.update_address'))
      # expect address page to have fields populated with address from state id
      expect(page).to have_field(
        t('idv.form.address1'),
        with: InPersonHelper::GOOD_IDENTITY_DOC_ADDRESS1,
      )

      # change part of the address
      fill_in t('idv.form.address1'), with: 'new address different from state address1'
      # click update
      click_button t('forms.buttons.submit.update')

      # verify page
      expect(page).to have_current_path(idv_in_person_verify_info_path)
      expect(page).to have_content(t('headings.verify'))
      expect(page).to have_text('new address different from state address1').once

      # click update state id address
      click_button t('idv.buttons.change_state_id_label')

      # check that the "No, I live at a different address" is checked
      expect(page).to have_checked_field(
        t('in_person_proofing.form.state_id.same_address_as_id_no'),
        visible: false,
      )
    end
  end

  context 'Outage alert enabled' do
    let(:user) { user_with_2fa }

    before do
      allow(IdentityConfig.store).to receive(:in_person_outage_message_enabled).and_return(true)
    end

    it 'allows the user to generate a barcode despite outage', allow_browser_log: true do
      sign_in_and_2fa_user(user)
      begin_in_person_proofing(user)

      # alert is visible on prepare page
      expect(page).to have_content(
        t(
          'idv.failure.exceptions.in_person_outage_error_message.post_cta.body',
          app_name: APP_NAME,
        ),
      )
      complete_all_in_person_proofing_steps
      complete_phone_step(user)
      complete_enter_password_step(user)
      acknowledge_and_confirm_personal_key

      # alert is visible on ready to verify page
      expect(page).to have_content(
        t('idv.failure.exceptions.in_person_outage_error_message.ready_to_verify.body'),
      )
      expect(page).to have_current_path(idv_in_person_ready_to_verify_path, wait: 10)
    end
  end

  context 'when full form address entry is enabled for post office search' do
    let(:user) { user_with_2fa }

    before do
      allow(IdentityConfig.store).to receive(:in_person_full_address_entry_enabled).and_return(true)
    end

    it 'allows the user to search by full address', allow_browser_log: true do
      sign_in_and_2fa_user(user)
      begin_in_person_proofing(user)
      # prepare page
      complete_prepare_step(user)

      # location page
      complete_location_step

      # state ID page
      complete_state_id_step(user, same_address_as_id: false)

      # address page
      complete_address_step(user, same_address_as_id: false)

      # ssn page
      complete_ssn_step(user, 'Reject')

      # verify page
      expect_in_person_step_indicator_current_step(t('step_indicator.flows.idv.verify_info'))
      expect(page).to have_content(t('headings.verify'))
      expect(page).to have_current_path(idv_in_person_verify_info_path)
      expect(page).to have_text(InPersonHelper::GOOD_FIRST_NAME)
      expect(page).to have_text(InPersonHelper::GOOD_LAST_NAME)
      expect(page).to have_text(InPersonHelper::GOOD_DOB_FORMATTED_EVENT)
      expect(page).to have_text(InPersonHelper::GOOD_STATE_ID_NUMBER)
      expect(page).to have_text(InPersonHelper::GOOD_IDENTITY_DOC_ADDRESS1)
      expect(page).to have_text(InPersonHelper::GOOD_IDENTITY_DOC_ADDRESS2)
      expect(page).to have_text(InPersonHelper::GOOD_IDENTITY_DOC_CITY)
      expect(page).to have_text(Idp::Constants::MOCK_IDV_APPLICANT[:state_id_jurisdiction]).twice
      expect(page).to have_text(InPersonHelper::GOOD_IDENTITY_DOC_ZIPCODE)
      expect(page).to have_text(InPersonHelper::GOOD_ADDRESS1)
      expect(page).to have_text(InPersonHelper::GOOD_CITY)
      expect(page).to have_text(InPersonHelper::GOOD_ZIPCODE)
      expect(page).to have_text(Idp::Constants::MOCK_IDV_APPLICANT[:state])
      expect(page).to have_text(DocAuthHelper::GOOD_SSN_MASKED)
      complete_verify_step(user)

      # phone page
      expect_in_person_step_indicator_current_step(
        t('step_indicator.flows.idv.verify_phone_or_address'),
      )
      expect(page).to have_content(t('titles.idv.phone'))
      fill_out_phone_form_ok(MfaContext.new(user).phone_configurations.first.phone)
      click_idv_send_security_code
      expect_in_person_step_indicator_current_step(
        t('step_indicator.flows.idv.verify_phone_or_address'),
      )

      expect_in_person_step_indicator_current_step(
        t('step_indicator.flows.idv.verify_phone_or_address'),
      )
      fill_in_code_with_last_phone_otp
      click_submit_default

      # password confirm page
      expect_in_person_step_indicator_current_step(t('step_indicator.flows.idv.secure_account'))
      expect(page).to have_content(t('idv.titles.session.enter_password', app_name: APP_NAME))
      complete_enter_password_step(user)

      # personal key page
      expect_in_person_step_indicator
      expect(page).not_to have_css('.step-indicator__step--current')
      expect(page).to have_content(t('titles.idv.personal_key'))
      deadline = nil
      freeze_time do
        acknowledge_and_confirm_personal_key
        deadline = (Time.zone.now +
          IdentityConfig.store.in_person_enrollment_validity_in_days.days).
          in_time_zone(Idv::InPerson::ReadyToVerifyPresenter::USPS_SERVER_TIMEZONE).
          strftime(t('time.formats.event_date'))
      end

      # ready to verify page
      expect_in_person_step_indicator_current_step(
        t('step_indicator.flows.idv.go_to_the_post_office'),
      )
      expect_page_to_have_no_accessibility_violations(page)
      enrollment_code = JSON.parse(
        UspsInPersonProofing::Mock::Fixtures.request_enroll_response,
      )['enrollmentCode']
      expect(page).to have_content(t('in_person_proofing.headings.barcode').tr(' ', ' '))
      expect(page).to have_content(Idv::InPerson::EnrollmentCodeFormatter.format(enrollment_code))
      expect(page).to have_content(
        t('in_person_proofing.body.barcode.deadline', deadline: deadline),
      )
      expect(page).to have_content('MILWAUKEE')
      expect(page).to have_content('Sunday: Closed')

      # signing in again before completing in-person proofing at a post office
      Capybara.reset_session!
      sign_in_live_with_2fa(user)
      visit_idp_from_sp_with_ial2(:oidc)
      expect(page).to have_current_path(idv_in_person_ready_to_verify_path)
    end
  end
end
