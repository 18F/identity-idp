require 'rails_helper'

RSpec.describe Idv::InPerson::ReadyToVerifyPresenter do
  let(:user) { build(:user) }
  let(:profile) { build(:profile, user: user) }
  let(:current_address_matches_id) { true }
  let(:created_at) { described_class::USPS_SERVER_TIMEZONE.parse('2022-07-14T00:00:00Z') }
  let(:enrollment_established_at) do
    described_class::USPS_SERVER_TIMEZONE.parse('2022-08-14T00:00:00Z')
  end
  let(:enrollment_selected_location_details) do
    JSON.parse(UspsInPersonProofing::Mock::Fixtures.enrollment_selected_location_details)
  end
  let(:enrollment) do
    create(
      :in_person_enrollment, :with_service_provider, :pending,
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
    subject(:formatted_due_date) { presenter.formatted_due_date }

    around do |example|
      Time.use_zone('UTC') { example.run }
    end

    it 'returns a formatted due date' do
      expect(formatted_due_date).to eq 'September 12, 2022'
    end

    context 'there is no enrollment_established_at' do
      let(:enrollment_established_at) { nil }
      it 'returns formatted due date when no enrollment_established_at' do
        expect(formatted_due_date).to eq 'August 12, 2022'
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
    let(:hours_open) { '8:00 AM - 4:30 PM' }
    let(:hours_closed) { 'Closed' }

    before do
      allow(presenter).to receive(:selected_location_details).and_return(
        {
          'weekday_hours' => hours_open,
          'saturday_hours' => hours_open,
          'sunday_hours' => hours_closed,
        },
      )
    end

    it 'returns localized location hours for weekdays and weekends by prefix' do
      expect(presenter.selected_location_hours(:weekday)).to eq '8:00 AM – 4:30 PM'
      expect(presenter.selected_location_hours(:saturday)).to eq '8:00 AM – 4:30 PM'
      expect(presenter.selected_location_hours(:sunday)).to eq(
        I18n.t('in_person_proofing.body.barcode.retail_hours_closed'),
      )
    end

    context 'with Spanish locale' do
      before { I18n.locale = :es }

      it 'returns localized location hours for weekdays and weekends by prefix' do
        expect(presenter.selected_location_hours(:weekday)).to eq '08:00 – 16:30'
        expect(presenter.selected_location_hours(:saturday)).to eq '08:00 – 16:30'
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
      allow(IdentityConfig.store).to receive(:in_person_outage_expected_update_date).
        and_return(in_person_outage_expected_update_date)
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
      allow(IdentityConfig.store).to receive(:in_person_outage_emailed_by_date).
        and_return(in_person_outage_emailed_by_date)
      email_day, email_month = email_date.remove(',').split(' ')

      expect(Date::DAYNAMES.include?(email_day && email_day.capitalize)).to be_truthy
      expect(Date::MONTHNAMES.include?(email_month && email_month.capitalize)).to be_truthy
      expect(email_date).to eq 'Tuesday, January 2'
    end
  end

  describe '#outage_message_enabled' do
    subject(:outage_message_enabled) { presenter.outage_message_enabled? }

    it 'returns true when the flag is enabled' do
      allow(IdentityConfig.store).to receive(:in_person_outage_message_enabled).
        and_return(true).once
      expect(outage_message_enabled).to be(true)
    end

    it 'returns false when the flag is disabled' do
      allow(IdentityConfig.store).to receive(:in_person_outage_message_enabled).
        and_return(false).once
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
end
