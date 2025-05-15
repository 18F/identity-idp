require 'rails_helper'

RSpec.describe Idv::InPerson::ReadyToVerifyPresenter do
  let(:user) { build(:user) }
  let(:profile) { build(:profile, user: user) }
  let(:current_address_matches_id) { true }
  let(:created_at) { described_class::USPS_SERVER_TIMEZONE.parse('2023-06-14T00:00:00Z') }
  let(:enrollment_established_at) do
    described_class::USPS_SERVER_TIMEZONE.parse('2023-07-14T00:00:00Z')
  end
  let(:enrollment_selected_location_details) do
    JSON.parse(UspsInPersonProofing::Mock::Fixtures.enrollment_selected_location_details)
  end
  let(:enrollment) do
    create(
      :in_person_enrollment, :with_service_provider, :pending, :state_id,
      user: user,
      profile: profile,
      created_at: created_at,
      enrollment_established_at: enrollment_established_at,
      current_address_matches_id: current_address_matches_id,
      selected_location_details: enrollment_selected_location_details
    )
  end
  subject(:presenter) { described_class.new(enrollment: enrollment) }

  describe '#formatted_due_date' do
    let(:enrollment_established_at) { DateTime.new(2024, 7, 5) }

    context 'when the enrollment has an enrollment_established_at time' do
      [
        ['English', :en, 'August 3, 2024'],
        ['Spanish', :es, '3 de agosto de 2024'],
        ['French', :fr, '3 août 2024'],
        ['Chinese', :zh, '2024年8月3日'],
      ].each do |language, locale, expected|
        context "when locale is #{language}" do
          before do
            I18n.locale = locale
          end

          it "returns the formatted due date in #{language}" do
            expect(presenter.formatted_due_date).to eq(expected)
          end
        end
      end
    end

    context 'when the enrollment does not have an enrollment_established_at time' do
      let(:enrollment_established_at) { nil }
      it 'returns formatted due date when no enrollment_established_at' do
        expect(presenter.formatted_due_date).to eq 'July 13, 2023'
      end
    end
  end

  describe '#selected_location_details' do
    subject(:selected_location_details) { presenter.selected_location_details }

    it 'returns a hash of location details associated with the enrollment' do
      expect(selected_location_details).to include(
        'formatted_city_state_zip' => kind_of(String),
        'name' => kind_of(String),
        'saturday_hours' => kind_of(String),
        'street_address' => kind_of(String),
        'sunday_hours' => kind_of(String),
        'weekday_hours' => kind_of(String),
      )
    end

    context 'with blank selected_location_details' do
      let(:enrollment_selected_location_details) { nil }

      it 'returns nil' do
        expect(selected_location_details).to be_nil
      end
    end
  end

  describe '#selected_location_hours' do
    it 'returns localized location hours for weekdays and weekends by prefix' do
      expect(presenter.selected_location_hours(:weekday)).to eq '9:00 AM – 5:00 PM'
      expect(presenter.selected_location_hours(:saturday)).to eq '9:00 AM – 1:00 PM'
      expect(presenter.selected_location_hours(:sunday)).to eq(
        I18n.t('in_person_proofing.body.barcode.retail_hours_closed'),
      )
    end

    context 'with previously localized hours' do
      let(:enrollment_selected_location_details) do
        json = JSON.parse(UspsInPersonProofing::Mock::Fixtures.enrollment_selected_location_details)
        json['weekday_hours'] = UspsInPersonProofing::EnrollmentHelper.localized_hours(
          json['weekday_hours'],
        )
        json['saturday_hours'] = UspsInPersonProofing::EnrollmentHelper.localized_hours(
          json['saturday_hours'],
        )
        json['sunday_hours'] = UspsInPersonProofing::EnrollmentHelper.localized_hours(
          json['sunday_hours'],
        )
        json
      end

      it 'localizes appropriately' do
        expect(presenter.selected_location_hours(:weekday)).to eq '9:00 AM – 5:00 PM'
        expect(presenter.selected_location_hours(:saturday)).to eq '9:00 AM – 1:00 PM'
        expect(presenter.selected_location_hours(:sunday)).to eq(
          I18n.t('in_person_proofing.body.barcode.retail_hours_closed'),
        )
      end
    end

    context 'with Spanish locale' do
      before { I18n.locale = :es }

      it 'returns localized location hours for weekdays and weekends by prefix' do
        expect(presenter.selected_location_hours(:weekday)).to eq '9:00 AM – 5:00 PM'
        expect(presenter.selected_location_hours(:saturday)).to eq '9:00 AM – 1:00 PM'
        expect(presenter.selected_location_hours(:sunday)).to eq(
          I18n.t('in_person_proofing.body.barcode.retail_hours_closed'),
        )
      end
    end

    context 'with French locale' do
      before { I18n.locale = :fr }

      it 'returns localized location hours for weekdays and weekends by prefix' do
        expect(presenter.selected_location_hours(:weekday)).to eq '9 h 00 AM – 5 h 00 PM'
        expect(presenter.selected_location_hours(:saturday)).to eq '9 h 00 AM – 1 h 00 PM'
        expect(presenter.selected_location_hours(:sunday)).to eq(
          I18n.t('in_person_proofing.body.barcode.retail_hours_closed'),
        )
      end
    end

    context 'with Chinese locale' do
      before { I18n.locale = :zh }

      it 'returns localized location hours for weekdays and weekends by prefix' do
        expect(presenter.selected_location_hours(:weekday)).to eq '9:00 AM – 5:00 PM'
        expect(presenter.selected_location_hours(:saturday)).to eq '9:00 AM – 1:00 PM'
        expect(presenter.selected_location_hours(:sunday)).to eq(
          I18n.t('in_person_proofing.body.barcode.retail_hours_closed'),
        )
      end
    end
  end

  describe '#sp_name' do
    subject(:sp_name) { presenter.sp_name }

    it 'returns friendly service provider name' do
      expect(sp_name).to eq('Test Service Provider')
    end
  end

  describe '#days_remaining' do
    subject(:days_remaining) { presenter.days_remaining }
    let(:config) { IdentityConfig.store.in_person_enrollment_validity_in_days }

    context '4 days until due date' do
      it 'returns 3 days' do
        travel_to(enrollment_established_at + (config - 4).days) do
          expect(days_remaining).to eq(3)
        end
      end
    end
  end

  describe '#formatted_outage_expected_update_date' do
    let(:in_person_outage_expected_update_date) { 'January 1, 2024' }
    subject(:update_date) { presenter.formatted_outage_expected_update_date }

    it 'returns a formatted date for expected update after an outage' do
      allow(IdentityConfig.store).to receive(:in_person_outage_expected_update_date)
        .and_return(in_person_outage_expected_update_date)
      update_day, update_month = update_date.remove(',').split(' ')

      expect(Date::DAYNAMES.include?(update_day && update_day.capitalize)).to be_truthy
      expect(Date::MONTHNAMES.include?(update_month && update_month.capitalize)).to be_truthy
      expect(update_date).to eq 'Monday, January 1'
    end
  end

  describe '#formatted_outage_emailed_by_date' do
    let(:in_person_outage_emailed_by_date) { 'January 2, 2024' }
    subject(:email_date) { presenter.formatted_outage_emailed_by_date }

    it 'returns a formatted email date' do
      allow(IdentityConfig.store).to receive(:in_person_outage_emailed_by_date)
        .and_return(in_person_outage_emailed_by_date)
      email_day, email_month = email_date.remove(',').split(' ')

      expect(Date::DAYNAMES.include?(email_day && email_day.capitalize)).to be_truthy
      expect(Date::MONTHNAMES.include?(email_month && email_month.capitalize)).to be_truthy
      expect(email_date).to eq 'Tuesday, January 2'
    end
  end

  describe '#outage_message_enabled' do
    subject(:outage_message_enabled) { presenter.outage_message_enabled? }

    it 'returns true when the flag is enabled' do
      allow(IdentityConfig.store).to receive(:in_person_outage_message_enabled)
        .and_return(true).once
      expect(outage_message_enabled).to be(true)
    end

    it 'returns false when the flag is disabled' do
      allow(IdentityConfig.store).to receive(:in_person_outage_message_enabled)
        .and_return(false).once
      expect(outage_message_enabled).to be(false)
    end
  end

  describe '#barcode_image_url' do
    subject(:barcode_image_url) { presenter.barcode_image_url }

    it { expect(barcode_image_url).to be_nil }

    context 'with barcode url' do
      let(:barcode_url) { 'https://example.com/barcode.png' }
      subject(:presenter) do
        described_class.new(enrollment: enrollment, barcode_image_url: barcode_url)
      end

      it 'returns barcode url' do
        expect(barcode_image_url).to eq(barcode_url)
      end
    end
  end

  describe 'enrollments created with a state ID' do
    it 'returns false for enrolled_with_passport_book?' do
      expect(presenter.enrolled_with_passport_book?).to be(false)
    end

    it 'displays state ID specific content' do
      expect(presenter.barcode_heading_text).to eq(t('in_person_proofing.headings.barcode'))
      expect(presenter.state_id_heading_text).to eq(
        t('in_person_proofing.process.state_id.heading'),
      )
      expect(presenter.state_id_info).to eq(t('in_person_proofing.process.state_id.info'))
      # not passport specific content
      expect(presenter.barcode_heading_text).to_not eq(
        t('in_person_proofing.headings.barcode_passport'),
      )
      expect(presenter.state_id_heading_text).to_not eq(
        t('in_person_proofing.process.passport.heading'),
      )
      expect(presenter.state_id_info).to_not eq(t('in_person_proofing.process.passport.info'))
      # not eipp specific content
      expect(presenter.barcode_heading_text).to_not eq(
        t('in_person_proofing.headings.barcode_eipp'),
      )
      expect(presenter.state_id_heading_text).to_not eq(
        t('in_person_proofing.process.state_id.heading_eipp'),
      )
      expect(presenter.state_id_info).to_not eq(t('in_person_proofing.process.state_id.info_eipp'))
    end
  end

  describe 'enrollments created with a passport' do
    let(:enrollment) do
      create(
        :in_person_enrollment, :with_service_provider, :pending, :passport_book,
        user: user,
        profile: profile,
        created_at: created_at,
        enrollment_established_at: enrollment_established_at,
        current_address_matches_id: current_address_matches_id,
        selected_location_details: enrollment_selected_location_details
      )
    end
    subject(:presenter) { described_class.new(enrollment: enrollment) }

    it 'returns true for enrolled_with_passport_book?' do
      expect(presenter.enrolled_with_passport_book?).to be(true)
    end

    it 'displays passport specific content' do
      expect(presenter.barcode_heading_text).to eq(
        t('in_person_proofing.headings.barcode_passport'),
      )
      expect(presenter.state_id_heading_text).to eq(
        t('in_person_proofing.process.passport.heading'),
      )
      expect(presenter.state_id_info).to eq(t('in_person_proofing.process.passport.info'))
      # not state id specific content
      expect(presenter.barcode_heading_text).to_not eq(t('in_person_proofing.headings.barcode'))
      expect(presenter.state_id_heading_text).to_not eq(
        t('in_person_proofing.process.state_id.heading'),
      )
      expect(presenter.state_id_info).to_not eq(t('in_person_proofing.process.state_id.info'))
      # not eipp specific content
      expect(presenter.barcode_heading_text).to_not eq(
        t('in_person_proofing.headings.barcode_eipp'),
      )
      expect(presenter.state_id_heading_text).to_not eq(
        t('in_person_proofing.process.state_id.heading_eipp'),
      )
      expect(presenter.state_id_info).to_not eq(t('in_person_proofing.process.state_id.info_eipp'))
    end

    describe 'eipp enrollments' do
      let(:enrollment) do
        create(
          :in_person_enrollment, :with_service_provider, :pending, :state_id, :enhanced_ipp,
          user: user,
          profile: profile,
          created_at: created_at,
          enrollment_established_at: enrollment_established_at,
          current_address_matches_id: current_address_matches_id,
          selected_location_details: enrollment_selected_location_details
        )
      end
      subject(:presenter) { described_class.new(enrollment: enrollment) }

      it 'returns false for enrolled_with_passport_book?' do
        expect(presenter.enrolled_with_passport_book?).to be(false)
      end

      it 'displays eipp specific content' do
        expect(presenter.barcode_heading_text).to eq(t('in_person_proofing.headings.barcode_eipp'))
        expect(presenter.state_id_heading_text).to eq(
          t('in_person_proofing.process.state_id.heading_eipp'),
        )
        expect(presenter.state_id_info).to eq(t('in_person_proofing.process.state_id.info_eipp'))
        # not state id specific content
        expect(presenter.barcode_heading_text).to_not eq(t('in_person_proofing.headings.barcode'))
        expect(presenter.state_id_heading_text).to_not eq(
          t('in_person_proofing.process.state_id.heading'),
        )
        expect(presenter.state_id_info).to_not eq(t('in_person_proofing.process.state_id.info'))
        # not passport specific content
        expect(presenter.barcode_heading_text).to_not eq(
          t('in_person_proofing.headings.barcode_passport'),
        )
        expect(presenter.state_id_heading_text).to_not eq(
          t('in_person_proofing.process.passport.heading'),
        )
        expect(presenter.state_id_info).to_not eq(t('in_person_proofing.process.passport.info'))
      end
    end
  end
end
