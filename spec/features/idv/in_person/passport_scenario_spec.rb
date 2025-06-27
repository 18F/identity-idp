## frozen_string_literal: true

require 'rails_helper'
require 'axe-rspec'

RSpec.describe 'In Person Proofing Passports', js: true do
  include IdvStepHelper
  include InPersonHelper
  include AbTestsHelper
  include PassportApiHelpers

  let(:service_provider) { :oidc }
  let(:user) { user_with_2fa }
  let(:service_provider_name) { 'Test SP' }

  before do
    ServiceProvider.find_by(issuer: service_provider_issuer(service_provider))
      .update(in_person_proofing_enabled: true)
    allow(IdentityConfig.store).to receive(:in_person_proofing_opt_in_enabled).and_return(true)
    allow(IdentityConfig.store).to receive(:in_person_proofing_enabled).and_return(true)
  end

  context 'when passports are not allowed' do
    before do
      allow(IdentityConfig.store).to receive(:doc_auth_passports_enabled).and_return(false)
    end

    context 'when in person passports are enabled' do
      before do
        allow(IdentityConfig.store).to receive(:in_person_passports_enabled).and_return(true)
      end

      it 'does not allow the user to access in person passport content' do
        reload_ab_tests
        visit_idp_from_sp_with_ial2(service_provider)
        sign_in_live_with_2fa(user)

        expect(page).to have_current_path(idv_welcome_path)
        expect(page).to have_content t('doc_auth.headings.welcome', sp_name: service_provider_name)
        expect(page).to have_content t('doc_auth.instructions.bullet1a')

        complete_welcome_step

        expect(page).to have_current_path(idv_agreement_path)
        complete_agreement_step

        expect(page).to_not have_content t('doc_auth.info.verify_online_description_passport')
        expect(page).to_not have_content strip_tags(
          t('doc_auth.info.verify_at_post_office_description_passport_html'),
        )

        click_on t('forms.buttons.continue_ipp')

        expect(page).to have_current_path(idv_document_capture_path(step: 'hybrid_handoff'))

        click_on t('forms.buttons.continue')
        complete_location_step(user)

        expect(page).to have_current_path(idv_in_person_state_id_path)
      end
    end
  end

  def fill_in_passport_form
    fill_in t('in_person_proofing.form.passport.surname'),
            with: InPersonHelper::GOOD_LAST_NAME
    fill_in t('in_person_proofing.form.passport.first_name'),
            with: InPersonHelper::GOOD_FIRST_NAME

    fill_in_memorable_date(
      'in_person_passport[passport_dob]',
      InPersonHelper::GOOD_DOB,
    )

    fill_in t('in_person_proofing.form.passport.passport_number'),
            with: InPersonHelper::GOOD_PASSPORT_NUMBER

    fill_in_memorable_date(
      'in_person_passport[passport_expiration]',
      InPersonHelper::GOOD_PASSPORT_EXPIRATION_DATE,
    )
  end

  def check_passport_verify_info_page_content
    expect(page).to have_content t('in_person_proofing.form.verify_info.passport')

    # Surname
    expect(page).to have_content t('in_person_proofing.form.passport.surname')
    expect(page).to have_content InPersonHelper::GOOD_LAST_NAME
    # First name
    expect(page).to have_content t('in_person_proofing.form.passport.first_name')
    expect(page).to have_content InPersonHelper::GOOD_FIRST_NAME
    # Date of Birth
    expect(page).to have_content t('in_person_proofing.form.passport.dob')
    expect(page).to have_content(
      I18n.l(Date.parse(InPersonHelper::GOOD_DOB), format: t('time.formats.event_date')),
    )

    expect(page).to have_content(t('headings.residential_address'))
    # address 1
    expect(page).to have_content(t('idv.form.address1'))
    expect(page).to have_content InPersonHelper::GOOD_ADDRESS1
    # address 2
    expect(page).to have_content(t('idv.form.address2'))
    expect(page).to have_content InPersonHelper::GOOD_ADDRESS2
    # address city
    expect(page).to have_content(t('idv.form.city'))
    expect(page).to have_content InPersonHelper::GOOD_CITY
    # address state
    expect(page).to have_content(t('idv.form.state'))
    expect(page).to have_content InPersonHelper::GOOD_STATE_ABBR
    # address zipcode
    expect(page).to have_content(t('idv.form.zipcode'))
    expect(page).to have_content InPersonHelper::GOOD_ZIPCODE

    expect(page).to have_content(t('headings.ssn'))
    expect(page).to have_content(t('idv.form.ssn'))
    expect(page).to have_content SsnFormatter.format_masked(InPersonHelper::GOOD_SSN)

    expect(page).to_not have_content(t('headings.state_id'))
    expect(page).to_not have_content(t('idv.form.id_number'))
  end
end
