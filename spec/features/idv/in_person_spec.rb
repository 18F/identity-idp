require 'rails_helper'
require 'axe-rspec'

RSpec.describe 'In Person Proofing', js: true do
  include IdvStepHelper
  include SpAuthHelper
  include InPersonHelper

  before do
    allow(IdentityConfig.store).to receive(:in_person_proofing_enabled).and_return(true)
    allow(IdentityConfig.store).to receive(:in_person_capture_secondary_id_enabled).
      and_return(false)
  end

  context 'ThreatMetrix review pending' do
    let(:user) { user_with_2fa }

    before do
      allow(IdentityConfig.store).to receive(:proofing_device_profiling).and_return(:enabled)
      allow(IdentityConfig.store).to receive(:lexisnexis_threatmetrix_org_id).and_return('test_org')
    end

    it 'allows the user to continue down the happy path', allow_browser_log: true do
      sign_in_and_2fa_user(user)
      begin_in_person_proofing(user)
      # prepare page
      complete_prepare_step(user)

      # location page
      complete_location_step

      # state ID page
      complete_state_id_step(user)

      # address page
      complete_address_step(user)

      # ssn page
      select 'Reject', from: :mock_profiling_result
      complete_ssn_step(user)

      # verify page
      expect_in_person_step_indicator_current_step(t('step_indicator.flows.idv.verify_info'))
      expect(page).to have_content(t('headings.verify'))
      expect(page).to have_current_path(idv_in_person_verify_info_path)
      expect(page).to have_text(InPersonHelper::GOOD_FIRST_NAME)
      expect(page).to have_text(InPersonHelper::GOOD_LAST_NAME)
      expect(page).to have_text(InPersonHelper::GOOD_DOB_FORMATTED_EVENT)
      expect(page).to have_text(InPersonHelper::GOOD_STATE_ID_NUMBER)
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
      expect(page).to have_content(t('idv.titles.session.review', app_name: APP_NAME))
      complete_review_step(user)

      # personal key page
      expect_in_person_step_indicator_current_step(t('step_indicator.flows.idv.secure_account'))
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
      expect(page).to have_current_path(idv_in_person_ready_to_verify_path)
    end
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

    # address page
    expect_in_person_step_indicator_current_step(t('step_indicator.flows.idv.verify_info'))
    expect(page).to have_content(t('in_person_proofing.headings.address'))
    expect(page).to have_content(t('in_person_proofing.form.address.same_address').tr(' ', ' '))
    complete_address_step(user)

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
    expect(page).to have_text(InPersonHelper::GOOD_ADDRESS1)
    expect(page).to have_text(InPersonHelper::GOOD_CITY)
    expect(page).to have_text(InPersonHelper::GOOD_ZIPCODE)
    expect(page).to have_text(Idp::Constants::MOCK_IDV_APPLICANT[:state])
    expect(page).to have_text(DocAuthHelper::GOOD_SSN_MASKED)

    # click update state ID button
    click_button t('idv.buttons.change_state_id_label')
    expect(page).to have_content(t('in_person_proofing.headings.update_state_id'))
    click_button t('forms.buttons.submit.update')
    expect(page).to have_content(t('headings.verify'))
    expect(page).to have_current_path(idv_in_person_verify_info_path)

    # click update address button
    click_button t('idv.buttons.change_address_label')
    expect(page).to have_content(t('in_person_proofing.headings.update_address'))
    choose t('in_person_proofing.form.address.same_address_choice_yes')
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
    expect(page).to have_current_path(idv_in_person_ready_to_verify_path)

    # confirm that user cannot visit other IdV pages before completing in-person proofing
    visit idv_agreement_path
    expect(page).to have_current_path(idv_in_person_ready_to_verify_path)
    visit idv_ssn_url
    expect(page).to have_current_path(idv_in_person_ready_to_verify_path)
    visit idv_verify_info_url
    expect(page).to have_current_path(idv_in_person_ready_to_verify_path)
  end

  it 'allows the user to cancel and start over from the beginning', allow_browser_log: true do
    user = sign_in_and_2fa_user
    begin_in_person_proofing
    complete_all_in_person_proofing_steps
    complete_phone_step(user)
    complete_review_step(user)
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

    it 'resumes desktop session with in-person proofing', allow_browser_log: true do
      user = nil

      perform_in_browser(:desktop) do
        user = sign_in_and_2fa_user
        complete_doc_auth_steps_before_hybrid_handoff_step
        clear_and_fill_in(:doc_auth_phone, '415-555-0199')
        click_send_link

        expect(page).to have_content(t('doc_auth.headings.text_message'))
      end

      expect(@sms_link).to be_present

      perform_in_browser(:mobile) do
        # doc auth page
        visit @sms_link
        mock_doc_auth_attention_with_barcode
        attach_and_submit_images

        # error page
        click_button t('in_person_proofing.body.cta.button')
        # prepare page
        expect(page).to(have_content(t('in_person_proofing.body.prepare.verify_step_about')))
        click_idv_continue
        # location page
        expect(page).to have_content(t('in_person_proofing.headings.po_search.location'))
        complete_location_step

        # switch back page
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

        expect(page).to have_content('MILWAUKEE')
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
      expect_in_person_gpo_step_indicator_current_step(t('step_indicator.flows.idv.get_a_letter'))
      complete_review_step

      expect_in_person_gpo_step_indicator_current_step(t('step_indicator.flows.idv.get_a_letter'))
      expect(page).to have_content(t('idv.titles.come_back_later'))
      expect(page).to have_current_path(idv_come_back_later_path)

      click_idv_continue
      expect(page).to have_current_path(account_path)
      expect(page).not_to have_content(t('headings.account.verified_account'))
      click_on t('account.index.verification.reactivate_button')
      expect_in_person_gpo_step_indicator_current_step(t('step_indicator.flows.idv.get_a_letter'))
      click_button t('idv.gpo.form.submit')

      # personal key
      expect_in_person_step_indicator_current_step(t('step_indicator.flows.idv.secure_account'))
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
      complete_review_step
      click_idv_continue
      click_on t('account.index.verification.reactivate_button')
      click_on t('idv.messages.clear_and_start_over')
      click_idv_continue

      expect(page).to have_current_path(idv_welcome_path)
    end
  end

  context 'transliteration' do
    before(:each) do
      allow(IdentityConfig.store).to receive(:usps_ipp_transliteration_enabled).
        and_return(true)
    end

    context 'with double address verification' do
      let(:capture_secondary_id_enabled) { true }
      let(:double_address_verification) { true }
      let(:user) { user_with_2fa }
      let(:enrollment) { InPersonEnrollment.new(capture_secondary_id_enabled:) }

      before do
        allow(IdentityConfig.store).to receive(:in_person_capture_secondary_id_enabled).
          and_return(true)
        allow(user).to receive(:establishing_in_person_enrollment).
          and_return(enrollment)
      end

      it 'shows validation errors when double address verification is true',
         allow_browser_log: true do
        sign_in_and_2fa_user
        begin_in_person_proofing
        complete_prepare_step
        complete_location_step
        expect(page).to have_current_path(idv_in_person_step_path(step: :state_id), wait: 10)

        fill_out_state_id_form_ok(double_address_verification: double_address_verification)
        fill_in t('in_person_proofing.form.state_id.first_name'), with: 'T0mmy "Lee"'
        fill_in t('in_person_proofing.form.state_id.last_name'), with: 'Джейкоб'
        fill_in t('in_person_proofing.form.state_id.address1'), with: '#1 $treet'
        fill_in t('in_person_proofing.form.state_id.address2'), with: 'Gr@nd Lañe^'
        fill_in t('in_person_proofing.form.state_id.city'), with: 'B3st C!ty'
        click_idv_continue

        expect(page).to have_content(
          I18n.t(
            'in_person_proofing.form.state_id.errors.unsupported_chars',
            char_list: '", 0',
          ),
        )

        expect(page).to have_content(
          I18n.t(
            'in_person_proofing.form.state_id.errors.unsupported_chars',
            char_list: 'Д, б, е, ж, й, к, о',
          ),
        )

        expect(page).to have_content(
          I18n.t(
            'in_person_proofing.form.state_id.errors.unsupported_chars',
            char_list: '$',
          ),
        )

        expect(page).to have_content(
          I18n.t(
            'in_person_proofing.form.state_id.errors.unsupported_chars',
            char_list: '@, ^',
          ),
        )

        expect(page).to have_content(
          I18n.t(
            'in_person_proofing.form.state_id.errors.unsupported_chars',
            char_list: '!, 3',
          ),
        )

        # re-fill state id form with good inputs
        fill_in t('in_person_proofing.form.state_id.first_name'),
                with: InPersonHelper::GOOD_FIRST_NAME
        fill_in t('in_person_proofing.form.state_id.last_name'),
                with: InPersonHelper::GOOD_LAST_NAME
        fill_in t('in_person_proofing.form.state_id.address1'),
                with: InPersonHelper::GOOD_IDENTITY_DOC_ADDRESS1
        fill_in t('in_person_proofing.form.state_id.address2'),
                with: InPersonHelper::GOOD_IDENTITY_DOC_ADDRESS2
        fill_in t('in_person_proofing.form.state_id.city'),
                with: InPersonHelper::GOOD_IDENTITY_DOC_CITY
        click_idv_continue

        expect(page).to have_current_path(idv_in_person_step_path(step: :address), wait: 10)
      end

      it 'shows hints when user selects Puerto Rico as state',
         allow_browser_log: true do
        sign_in_and_2fa_user
        begin_in_person_proofing
        complete_prepare_step
        complete_location_step
        expect(page).to have_current_path(idv_in_person_step_path(step: :state_id), wait: 10)

        # state id page
        select 'Puerto Rico',
               from: t('in_person_proofing.form.state_id.identity_doc_address_state')

        expect(page).to have_content(I18n.t('in_person_proofing.form.state_id.address1_hint'))
        expect(page).to have_content(I18n.t('in_person_proofing.form.state_id.address2_hint'))

        # change state selection
        fill_out_state_id_form_ok(double_address_verification: true)
        expect(page).not_to have_content(I18n.t('in_person_proofing.form.state_id.address1_hint'))
        expect(page).not_to have_content(I18n.t('in_person_proofing.form.state_id.address2_hint'))

        # re-select puerto rico
        select 'Puerto Rico',
               from: t('in_person_proofing.form.state_id.identity_doc_address_state')
        click_idv_continue

        expect(page).to have_current_path(idv_in_person_step_path(step: :address))

        # address form
        select 'Puerto Rico',
               from: t('idv.form.state')
        expect(page).to have_content(I18n.t('in_person_proofing.form.state_id.address1_hint'))
        expect(page).to have_content(I18n.t('in_person_proofing.form.state_id.address2_hint'))

        # change selection
        fill_out_address_form_ok(double_address_verification: true)
        expect(page).not_to have_content(I18n.t('in_person_proofing.form.state_id.address1_hint'))
        expect(page).not_to have_content(I18n.t('in_person_proofing.form.state_id.address2_hint'))

        # re-select puerto rico
        select 'Puerto Rico',
               from: t('idv.form.state')
        click_idv_continue

        # ssn page
        expect(page).to have_current_path(idv_in_person_ssn_url)
        complete_ssn_step

        # verify page
        expect(page).to have_current_path(idv_in_person_verify_info_path)
        expect(page).to have_text('PR').twice

        # update state ID
        click_button t('idv.buttons.change_state_id_label')

        expect(page).to have_content(t('in_person_proofing.headings.update_state_id'))
        expect(page).to have_content(I18n.t('in_person_proofing.form.state_id.address1_hint'))
        expect(page).to have_content(I18n.t('in_person_proofing.form.state_id.address2_hint'))
        click_button t('forms.buttons.submit.update')

        # update address
        click_button t('idv.buttons.change_address_label')

        expect(page).to have_content(t('in_person_proofing.headings.update_address'))
        expect(page).to have_content(I18n.t('in_person_proofing.form.state_id.address1_hint'))
        expect(page).to have_content(I18n.t('in_person_proofing.form.state_id.address2_hint'))
      end
    end

    context 'without double address verification' do
      it 'shows validation errors when double address verification is false',
         allow_browser_log: true do
        sign_in_and_2fa_user
        begin_in_person_proofing
        complete_prepare_step
        complete_location_step
        expect(page).to have_current_path(idv_in_person_step_path(step: :state_id), wait: 10)

        fill_out_state_id_form_ok
        fill_in t('in_person_proofing.form.state_id.first_name'), with: 'T0mmy "Lee"'
        fill_in t('in_person_proofing.form.state_id.last_name'), with: 'Джейкоб'
        click_idv_continue

        expect(page).to have_content(
          I18n.t(
            'in_person_proofing.form.state_id.errors.unsupported_chars',
            char_list: '", 0',
          ),
        )

        expect(page).to have_content(
          I18n.t(
            'in_person_proofing.form.state_id.errors.unsupported_chars',
            char_list: 'Д, б, е, ж, й, к, о',
          ),
        )

        # re-fill form with good inputs
        fill_in t('in_person_proofing.form.state_id.first_name'),
                with: InPersonHelper::GOOD_FIRST_NAME
        fill_in t('in_person_proofing.form.state_id.last_name'),
                with: InPersonHelper::GOOD_LAST_NAME
        click_idv_continue

        expect(page).to have_current_path(idv_in_person_step_path(step: :address), wait: 10)
        fill_out_address_form_ok

        fill_in t('idv.form.address1'), with: 'Джордж'
        fill_in t('idv.form.address2_optional'), with: '(Nope) = %'
        fill_in t('idv.form.city'), with: 'Елена'
        click_idv_continue

        expect(page).to have_content(
          I18n.t(
            'in_person_proofing.form.address.errors.unsupported_chars',
            char_list: 'Д, д, ж, о, р',
          ),
        )

        expect(page).to have_content(
          I18n.t(
            'in_person_proofing.form.address.errors.unsupported_chars',
            char_list: '%, (, ), =',
          ),
        )

        expect(page).to have_content(
          I18n.t(
            'in_person_proofing.form.address.errors.unsupported_chars',
            char_list: 'Е, а, е, л, н',
          ),
        )

        # re-fill form with good inputs
        fill_in t('idv.form.address1'), with: InPersonHelper::GOOD_ADDRESS1
        fill_in t('idv.form.address2_optional'), with: InPersonHelper::GOOD_ADDRESS2
        fill_in t('idv.form.city'), with: InPersonHelper::GOOD_CITY
        click_idv_continue
        expect(page).to have_current_path(idv_in_person_ssn_url, wait: 10)
      end
    end
  end

  context 'in_person_capture_secondary_id_enabled feature flag disabled, then enabled during flow',
          allow_browser_log: true do
    let(:user) { user_with_2fa }

    before(:each) do
      allow(IdentityConfig.store).to receive(:in_person_capture_secondary_id_enabled).
        and_return(false)

      sign_in_and_2fa_user(user)
      begin_in_person_proofing(user)
      complete_prepare_step(user)
      complete_location_step(user)
    end

    it 'does not capture separate state id address from residential address' do
      allow(IdentityConfig.store).to receive(:in_person_capture_secondary_id_enabled).
        and_return(true)
      complete_state_id_step(user)
      complete_address_step(user)
      complete_ssn_step(user)
    end
  end

  shared_examples 'captures address with state id' do
    let(:user) { user_with_2fa }

    before(:each) do
      allow(IdentityConfig.store).to receive(:in_person_capture_secondary_id_enabled).
        and_return(true)

      sign_in_and_2fa_user(user)
      begin_in_person_proofing(user)
      complete_prepare_step(user)
      complete_location_step(user)
    end
    it 'successfully proceeds through the flow' do
      complete_state_id_step(user, same_address_as_id: false, double_address_verification: true)

      complete_address_step(user, double_address_verification: true)

      # Ensure the page submitted successfully
      expect(page).to have_content(t('idv.form.ssn_label'))
    end
  end

  context 'in_person_capture_secondary_id_enabled feature flag enabled', allow_browser_log: true do
    context 'flag remains enabled' do
      it_behaves_like 'captures address with state id'
    end

    context 'flag is then disabled' do
      before(:each) do
        allow(IdentityConfig.store).to receive(:in_person_capture_secondary_id_enabled).
          and_return(false)
      end

      it_behaves_like 'captures address with state id'
    end
  end

  context 'in_person_capture_secondary_id_enabled feature flag enabled and same address as id',
          allow_browser_log: true do
    let(:user) { user_with_2fa }

    before(:each) do
      allow(IdentityConfig.store).to receive(:in_person_capture_secondary_id_enabled).
        and_return(true)

      sign_in_and_2fa_user(user)
      begin_in_person_proofing(user)
      complete_prepare_step(user)
      complete_location_step(user)
    end

    it 'skips the address page' do
      complete_state_id_step(user, same_address_as_id: true, double_address_verification: true)
      # skip address step
      complete_ssn_step(user)
      # Ensure the page submitted successfully
      expect(page).to have_content(t('idv.form.ssn_label'))
    end

    it 'can redo the address page form even if that page is skipped' do
      complete_state_id_step(user, same_address_as_id: true, double_address_verification: true)
      # skip address step
      complete_ssn_step(user)
      # click update address button on the verify page
      click_button t('idv.buttons.change_address_label')
      expect(page).to have_content(t('in_person_proofing.headings.update_address'))
      fill_out_address_form_ok(double_address_verification: true, same_address_as_id: true)
      click_button t('forms.buttons.submit.update')
      expect(page).to have_content(t('headings.verify'))
      expect(page).to have_current_path(idv_in_person_verify_info_path)
    end

    it 'allows user to update their residential address as different from their state id' do
      complete_state_id_step(user, same_address_as_id: true, double_address_verification: true)
      complete_ssn_step(user)

      # click "update residential address"
      click_button t('idv.buttons.change_address_label')
      expect(page).to have_content(t('in_person_proofing.headings.update_address'))
      # change something in the address
      fill_in t('idv.form.address1'), with: 'new address different from state address1'
      # click update
      click_button t('forms.buttons.submit.update')

      # back to verify page
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

  context 'in_person_capture_secondary_id_enabled feature flag enabled and' do
    context 'when updates are made on state ID page starting from Verify Your Information',
            allow_browser_log: true do
      let(:user) { user_with_2fa }

      before(:each) do
        allow(IdentityConfig.store).to receive(:in_person_capture_secondary_id_enabled).
          and_return(true)

        sign_in_and_2fa_user(user)
        begin_in_person_proofing(user)
        complete_prepare_step(user)
        complete_location_step(user)
      end

      it 'does not update their previous selection of "Yes,
      I live at the address on my state-issued ID"' do
        complete_state_id_step(user, same_address_as_id: true, double_address_verification: true)
        # skip address step
        complete_ssn_step(user)
        # expect to be on verify page
        expect(page).to have_content(t('headings.verify'))
        expect(page).to have_current_path(idv_in_person_verify_info_path)
        # click update state ID button on the verify page
        click_button t('idv.buttons.change_state_id_label')
        # expect to be on the state ID page
        expect(page).to have_content(t('in_person_proofing.headings.update_state_id'))
        # change address
        fill_in t('in_person_proofing.form.state_id.address1'), with: ''
        fill_in t('in_person_proofing.form.state_id.address1'), with: 'test update address'
        click_button t('forms.buttons.submit.update')
        # expect to be back on verify page
        expect(page).to have_content(t('headings.verify'))
        expect(page).to have_current_path(idv_in_person_verify_info_path)
        expect(page).to have_content(t('headings.verify'))
        # expect to see state ID address update on verify twice
        expect(page).to have_text('test update address').twice # for state id addr and addr update
        # click update state id address
        click_button t('idv.buttons.change_state_id_label')
        # expect to be on the state ID page
        expect(page).to have_content(t('in_person_proofing.headings.update_state_id'))
        # expect "Yes, I live at a different address" is checked"
        expect(page).to have_checked_field(
          t('in_person_proofing.form.state_id.same_address_as_id_yes'),
          visible: false,
        )
      end

      it 'does not update their previous selection of "No, I live at a different address"' do
        complete_state_id_step(user, same_address_as_id: false, double_address_verification: true)
        # expect to be on address page
        expect(page).to have_content(t('in_person_proofing.headings.address'))
        # complete address step
        complete_address_step(user, double_address_verification: true)
        complete_ssn_step(user)
        # expect to be back on verify page
        expect(page).to have_content(t('headings.verify'))
        expect(page).to have_current_path(idv_in_person_verify_info_path)
        # click update state ID button on the verify page
        click_button t('idv.buttons.change_state_id_label')
        # expect to be on the state ID page
        expect(page).to have_content(t('in_person_proofing.headings.update_state_id'))
        # change address
        fill_in t('in_person_proofing.form.state_id.address1'), with: ''
        fill_in t('in_person_proofing.form.state_id.address1'), with: 'test update address'
        click_button t('forms.buttons.submit.update')
        # expect to be back on verify page
        expect(page).to have_content(t('headings.verify'))
        expect(page).to have_current_path(idv_in_person_verify_info_path)
        expect(page).to have_content(t('headings.verify'))
        # expect to see state ID address update on verify
        expect(page).to have_text('test update address').once # only state id address update
        # click update state id address
        click_button t('idv.buttons.change_state_id_label')
        # expect to be on the state ID page
        expect(page).to have_content(t('in_person_proofing.headings.update_state_id'))
        expect(page).to have_checked_field(
          t('in_person_proofing.form.state_id.same_address_as_id_no'),
          visible: false,
        )
      end

      it 'updates their previous selection from "Yes" TO "No, I live at a different address"' do
        complete_state_id_step(user, same_address_as_id: true, double_address_verification: true)
        # skip address step
        complete_ssn_step(user)
        # click update state ID button on the verify page
        click_button t('idv.buttons.change_state_id_label')
        # expect to be on the state ID page
        expect(page).to have_content(t('in_person_proofing.headings.update_state_id'))
        # change address
        fill_in t('in_person_proofing.form.state_id.address1'), with: ''
        fill_in t('in_person_proofing.form.state_id.address1'), with: 'test update address'
        # change response to No
        choose t('in_person_proofing.form.state_id.same_address_as_id_no')
        click_button t('forms.buttons.submit.update')
        # expect to be on address page
        expect(page).to have_content(t('in_person_proofing.headings.address'))
        # complete address step
        complete_address_step(user, double_address_verification: true)
        # expect to be on verify page
        expect(page).to have_content(t('headings.verify'))
        expect(page).to have_current_path(idv_in_person_verify_info_path)
        # expect to see state ID address update on verify
        expect(page).to have_text('test update address').once # only state id address update
        # click update state id address
        click_button t('idv.buttons.change_state_id_label')
        # expect to be on the state ID page
        expect(page).to have_content(t('in_person_proofing.headings.update_state_id'))
        # check that the "No, I live at a different address" is checked"
        expect(page).to have_checked_field(
          t('in_person_proofing.form.state_id.same_address_as_id_no'),
          visible: false,
        )
      end

      it 'updates their previous selection from "No" TO "Yes,
      I live at the address on my state-issued ID"' do
        complete_state_id_step(user, same_address_as_id: false, double_address_verification: true)
        # expect to be on address page
        expect(page).to have_content(t('in_person_proofing.headings.address'))
        # complete address step
        complete_address_step(user, double_address_verification: true)
        complete_ssn_step(user)
        # expect to be on verify page
        expect(page).to have_content(t('headings.verify'))
        expect(page).to have_current_path(idv_in_person_verify_info_path)
        # click update state ID button on the verify page
        click_button t('idv.buttons.change_state_id_label')
        # expect to be on the state ID page
        expect(page).to have_content(t('in_person_proofing.headings.update_state_id'))
        # change address
        fill_in t('in_person_proofing.form.state_id.address1'), with: ''
        fill_in t('in_person_proofing.form.state_id.address1'), with: 'test update address'
        # change response to Yes
        choose t('in_person_proofing.form.state_id.same_address_as_id_yes')
        click_button t('forms.buttons.submit.update')
        # expect to be back on verify page
        expect(page).to have_content(t('headings.verify'))
        expect(page).to have_current_path(idv_in_person_verify_info_path)
        # expect to see state ID address update on verify twice
        expect(page).to have_text('test update address').twice # for state id addr and addr update
        # click update state ID button on the verify page
        click_button t('idv.buttons.change_state_id_label')
        # expect to be on the state ID page
        expect(page).to have_content(t('in_person_proofing.headings.update_state_id'))
        expect(page).to have_checked_field(
          t('in_person_proofing.form.state_id.same_address_as_id_yes'),
          visible: false,
        )
      end
    end
  end
  context 'when manual address entry is enabled for post office search' do
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
      complete_full_address_location_step

      # state ID page
      complete_state_id_step(user)

      # address page
      complete_address_step(user)

      # ssn page
      select 'Reject', from: :mock_profiling_result
      complete_ssn_step(user)

      # verify page
      expect_in_person_step_indicator_current_step(t('step_indicator.flows.idv.verify_info'))
      expect(page).to have_content(t('headings.verify'))
      expect(page).to have_current_path(idv_in_person_verify_info_path)
      expect(page).to have_text(InPersonHelper::GOOD_FIRST_NAME)
      expect(page).to have_text(InPersonHelper::GOOD_LAST_NAME)
      expect(page).to have_text(InPersonHelper::GOOD_DOB_FORMATTED_EVENT)
      expect(page).to have_text(InPersonHelper::GOOD_STATE_ID_NUMBER)
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
      expect(page).to have_content(t('idv.titles.session.review', app_name: APP_NAME))
      complete_review_step(user)

      # personal key page
      expect_in_person_step_indicator_current_step(t('step_indicator.flows.idv.secure_account'))
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
      expect(page).to have_current_path(idv_in_person_ready_to_verify_path)
    end
  end
end
