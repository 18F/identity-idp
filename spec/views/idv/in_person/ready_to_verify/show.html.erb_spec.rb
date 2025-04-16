require 'rails_helper'

RSpec.describe 'idv/in_person/ready_to_verify/show.html.erb' do
  include Devise::Test::ControllerHelpers

  let(:user) { build(:user) }
  let(:profile) { build(:profile, user: user) }
  let(:current_address_matches_id) { true }
  let(:selected_location_details) do
    JSON.parse(UspsInPersonProofing::Mock::Fixtures.enrollment_selected_location_details)
  end
  let(:created_at) { Time.zone.parse('2022-07-13') }
  let(:sp_url) { 'http://service.provider.gov' }
  let(:service_provider) { build(:service_provider, return_to_sp_url: sp_url) }
  let(:enrollment) do
    build(
      :in_person_enrollment, :pending,
      current_address_matches_id: current_address_matches_id,
      profile: profile,
      selected_location_details: selected_location_details,
      service_provider: service_provider,
      user: user
    )
  end
  let(:enhanced_ipp_enrollment) do
    build(
      :in_person_enrollment, :pending, :enhanced_ipp,
      current_address_matches_id: current_address_matches_id,
      profile: profile,
      selected_location_details: selected_location_details,
      service_provider: service_provider,
      user: user
    )
  end
  let(:presenter) do
    Idv::InPerson::ReadyToVerifyPresenter.new(
      enrollment: enrollment,
    )
  end
  let(:step_indicator_steps) { Idv::StepIndicatorConcern::STEP_INDICATOR_STEPS_IPP }
  let(:sp_event_name) { 'IdV: user clicked sp link on ready to verify page' }
  let(:help_event_name) { 'IdV: user clicked what to bring link on ready to verify page' }

  before do
    assign(:presenter, presenter)
    allow(view).to receive(:step_indicator_steps).and_return(step_indicator_steps)
  end

  it 'displays a link back to the help center' do
    render

    expect(rendered).to have_link(t('in_person_proofing.body.barcode.learn_more'))
    expect(rendered).to have_css("lg-click-observer[event-name='#{help_event_name}']")
    expect(rendered).to have_link(
      t('in_person_proofing.body.barcode.learn_more'),
      href: help_center_redirect_url(
        category: 'verify-your-identity',
        article: 'verify-your-identity-in-person',
      ),
    )
  end

  it 'renders the barcode deadline banner' do
    render

    expect(rendered).to have_content(
      t(
        'in_person_proofing.body.barcode.deadline',
        deadline: presenter.formatted_due_date,
        sp_name: presenter.sp_name,
      ),
    )
    expect(rendered).to have_content(t('in_person_proofing.body.barcode.deadline_restart'))
  end

  it 'renders a cancel link' do
    render

    expect(rendered).to have_link(
      t('in_person_proofing.body.barcode.cancel_link_text'),
      href: idv_cancel_path(step: 'barcode'),
    )
  end

  it 'displays a barcode label' do
    render

    expect(rendered).to have_content(t('in_person_proofing.process.barcode.caption_label'))
  end

  context 'link back to the service provider' do
    context 'when the user is coming from a service provider' do
      it 'displays a link back to the service provider' do
        render

        expect(rendered).to have_content(service_provider.friendly_name)
        expect(rendered).to have_css("lg-click-observer[event-name='#{sp_event_name}']")
      end
    end

    context 'when the user is not coming from a service provider' do
      let(:service_provider) { nil }

      it 'does not display a link back to the service provider' do
        render

        expect(rendered).not_to have_css("lg-click-observer[event-name='#{sp_event_name}']")
        expect(rendered).to have_content('You may now close this window')
      end
    end
  end

  context 'location section' do
    context 'when selected_location_details is present' do
      it 'renders a location' do
        render

        expect(rendered).to have_content(t('in_person_proofing.body.barcode.retail_hours'))
      end
    end

    context 'when selected_location_details is not present' do
      let(:selected_location_details) { nil }

      it 'does not render a location' do
        render

        expect(rendered).not_to have_content(t('in_person_proofing.body.barcode.retail_hours'))
      end
    end
  end

  context 'outage alert' do
    context 'when the outage message flag is enabled' do
      before do
        allow(IdentityConfig.store).to receive(:in_person_outage_message_enabled)
          .and_return(true)
      end

      context 'when the outage dates are included' do
        let(:formatted_date) { 'Tuesday, October 31' }
        let(:in_person_outage_emailed_by_date) { 'November 1, 2023' }
        let(:in_person_outage_expected_update_date) { 'October 31, 2023' }

        before do
          allow(IdentityConfig.store).to receive(:in_person_outage_emailed_by_date)
            .and_return(in_person_outage_emailed_by_date)
          allow(IdentityConfig.store).to receive(:in_person_outage_expected_update_date)
            .and_return(in_person_outage_expected_update_date)
        end

        it 'renders the outage alert' do
          render

          expect(rendered).to have_content(
            t(
              'idv.failure.exceptions.in_person_outage_error_message.ready_to_verify.title',
              date: formatted_date,
            ),
          )
        end
      end

      context 'when the outage dates are not included' do
        before do
          allow(IdentityConfig.store).to receive(:in_person_outage_message_enabled)
            .and_return(true)
          allow(IdentityConfig.store).to receive(:in_person_outage_emailed_by_date)
            .and_return('')
          allow(IdentityConfig.store).to receive(:in_person_outage_expected_update_date)
            .and_return('')
        end

        it 'does not render a warning' do
          render

          expect(rendered).to_not have_content(
            t('idv.failure.exceptions.in_person_outage_error_message.ready_to_verify.title'),
          )
        end
      end
    end

    context 'when the outage message flag is disabled' do
      before do
        allow(IdentityConfig.store).to receive(:in_person_outage_message_enabled)
          .and_return(false)
      end

      it 'does not render the outage alert' do
        render

        expect(rendered).not_to have_content(
          t('idv.failure.exceptions.in_person_outage_error_message.ready_to_verify.title'),
        )
      end
    end
  end

  context 'what to expect section' do
    context 'when the enrollment is ID-IPP' do
      it 'conditionally renders content applicable to ID-IPP' do
        render

        aggregate_failures do
          [
            t('in_person_proofing.headings.barcode'),
            t('in_person_proofing.process.state_id.heading'),
            t('in_person_proofing.process.state_id.info'),
          ].each do |copy|
            Array(copy).each do |part|
              expect(rendered).to have_content(part)
            end
          end
        end
      end
    end

    context 'when the enrollment is enhanced IPP' do
      let(:enrollment) { enhanced_ipp_enrollment }

      it 'conditionally renders content applicable to EIPP' do
        render

        aggregate_failures do
          [
            t('in_person_proofing.headings.barcode_eipp'),
            t('in_person_proofing.process.state_id.heading_eipp'),
            t('in_person_proofing.process.state_id.info_eipp'),
          ].each do |copy|
            Array(copy).each do |part|
              expect(rendered).to have_content(part)
            end
          end
        end
      end
    end
  end

  context 'Questions? and Learn more link' do
    it 'renders Questions? and Learn more link only once' do
      render

      expect(rendered).to have_content(t('in_person_proofing.body.barcode.questions')).once
      expect(rendered).to have_link(
        t('in_person_proofing.body.barcode.learn_more'),
        href: help_center_redirect_url(
          category: 'verify-your-identity',
          article: 'verify-your-identity-in-person',
        ),
      ).once
    end
  end

  context 'email sent success alert' do
    it 'renders the email sent success alert' do
      render

      expect(rendered).to have_content(t('in_person_proofing.body.barcode.email_sent'))
    end
  end

  context 'GSA Enhanced Pilot Barcode tag' do
    context 'when the enrollment is enhanced IPP' do
      let(:enrollment) { enhanced_ipp_enrollment }

      it 'renders GSA Enhanced Pilot Barcode tag' do
        render

        expect(rendered).to have_content(t('in_person_proofing.body.barcode.eipp_tag'))
      end
    end
    context 'when the enrollment is ID-IPP' do
      it 'does not render GSA Enhanced Pilot Barcode tag' do
        render

        expect(rendered).not_to have_content(t('in_person_proofing.body.barcode.eipp_tag'))
      end
    end
  end

  context 'What to bring to the Post Office section' do
    context 'when the enrollment is enhanced IPP' do
      let(:enrollment) { enhanced_ipp_enrollment }

      it 'displays heading and body' do
        render

        expect(rendered).to have_content(t('in_person_proofing.headings.barcode_what_to_bring'))
        expect(rendered).to have_content(t('in_person_proofing.body.barcode.eipp_what_to_bring'))
      end

      it 'renders Option 1 content' do
        render

        aggregate_failures do
          [
            t('in_person_proofing.process.eipp_bring_id.heading'),
            t('in_person_proofing.process.eipp_bring_id_with_current_address.heading'),
            t('in_person_proofing.process.eipp_bring_id.info'),
            t('in_person_proofing.process.real_id_and_supporting_docs.heading'),
            t('in_person_proofing.process.real_id_and_supporting_docs.info'),
          ].each do |copy|
            Array(copy).each do |part|
              expect(rendered).to have_content(part)
            end
          end
        end

        t('in_person_proofing.process.eipp_state_id_supporting_docs.info_list').each do |item|
          expect(rendered).to have_content(strip_tags(item))
        end
      end

      it 'renders Option 2 content' do
        render

        aggregate_failures do
          [
            t('in_person_proofing.process.eipp_bring_id_plus_documents.heading'),
            t('in_person_proofing.process.eipp_bring_id_plus_documents.info'),
            t('in_person_proofing.process.eipp_state_id_passport.heading'),
            t('in_person_proofing.process.eipp_state_id_passport.info'),
            t('in_person_proofing.process.eipp_state_id_military_id.heading'),
            t('in_person_proofing.process.eipp_state_id_military_id.info'),
            t('in_person_proofing.process.eipp_state_id_supporting_docs.heading'),
            t('in_person_proofing.process.eipp_state_id_supporting_docs.info'),
          ].each do |copy|
            Array(copy).each do |part|
              expect(rendered).to have_content(part)
            end
          end
        end

        t('in_person_proofing.process.eipp_state_id_supporting_docs.info_list').each do |item|
          expect(rendered).to have_content(strip_tags(item))
        end
      end
    end

    context 'when the enrollment is ID-IPP' do
      it 'template does not display Enhanced In-Person Proofing what to bring content' do
        render

        aggregate_failures do
          [
            t('in_person_proofing.headings.barcode_eipp'),
            t('in_person_proofing.headings.barcode_what_to_bring'),
            t('in_person_proofing.body.barcode.eipp_what_to_bring'),
            t('in_person_proofing.process.eipp_bring_id.heading'),
            t('in_person_proofing.process.eipp_bring_id_with_current_address.heading'),
            t('in_person_proofing.process.eipp_bring_id.info'),
            t('in_person_proofing.process.real_id_and_supporting_docs.heading'),
            t('in_person_proofing.process.real_id_and_supporting_docs.info'),
            t('in_person_proofing.process.eipp_bring_id_plus_documents.heading'),
            t('in_person_proofing.process.eipp_bring_id_plus_documents.info'),
            t('in_person_proofing.process.eipp_state_id_passport.heading'),
            t('in_person_proofing.process.eipp_state_id_passport.info'),
            t('in_person_proofing.process.eipp_state_id_military_id.heading'),
            t('in_person_proofing.process.eipp_state_id_military_id.info'),
            t('in_person_proofing.process.eipp_state_id_supporting_docs.heading'),
            t('in_person_proofing.process.eipp_state_id_supporting_docs.info'),
            t('in_person_proofing.process.state_id.heading_eipp'),
            t('in_person_proofing.process.state_id.info_eipp'),
          ].each do |copy|
            Array(copy).each do |part|
              expect(rendered).to_not have_content(part)
            end
          end
        end

        t('in_person_proofing.process.eipp_state_id_supporting_docs.info_list').each do |item|
          expect(rendered).to_not have_content(strip_tags(item))
        end
      end
    end
  end

  context 'Need to Change Location section' do
    context 'when the enrollment is ID-IPP' do
      it 'renders the change location heading' do
        render

        expect(rendered).to have_content(
          t('in_person_proofing.body.location.change_location_heading'),
        )
      end

      it 'renders the change location info' do
        render

        expect(rendered).to have_content(
          t(
            'in_person_proofing.body.location.change_location_info_html',
            find_other_locations_link_html:
              t('in_person_proofing.body.location.change_location_find_other_locations'),
          ),
        )
      end
    end

    context 'when Enhanced IPP is enabled' do
      let(:enrollment) { enhanced_ipp_enrollment }

      it 'does not render the change location heading' do
        render

        expect(rendered).not_to have_content(
          t('in_person_proofing.body.location.change_location_heading'),
        )
      end

      it 'does not render the change location info' do
        render

        expect(rendered).not_to have_content(
          t('in_person_proofing.body.location.change_location_info_html'),
        )
      end
    end
  end
end
