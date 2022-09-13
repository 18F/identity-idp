require 'rails_helper'

RSpec.describe Idv::InPerson::ReadyToVerifyPresenter do
  let(:user) { build(:user) }
  let(:profile) { build(:profile, user: user) }
  let(:enrollment_code) { '2048702198804358' }
  let(:current_address_matches_id) { true }
  let(:created_at) { described_class::USPS_SERVER_TIMEZONE.parse('2022-07-14T00:00:00Z') }
  let(:enrollment_established_at) { described_class::USPS_SERVER_TIMEZONE.parse('2022-08-14T00:00:00Z') }
  let(:enrollment_selected_location_details) do
    JSON.parse(UspsInPersonProofing::Mock::Fixtures.enrollment_selected_location_details)
  end
  let(:enrollment) do
    InPersonEnrollment.new(
      user: user,
      profile: profile,
      enrollment_code: enrollment_code,
      unique_id: InPersonEnrollment.generate_unique_id,
      enrollment_established_at:  enrollment_established_at,
      current_address_matches_id: current_address_matches_id,
      selected_location_details: enrollment_selected_location_details,
    )
  end
  let(:enrollment2) do
    InPersonEnrollment.new(
      created_at: created_at
    )
  end
  subject(:presenter) { described_class.new(enrollment: enrollment) }
  subject(:presenter2) {described_class.new(enrollment: enrollment2)}

  describe '#formatted_due_date' do
    subject(:formatted_due_date) { presenter.formatted_due_date }
    subject(:formatted_due_date_two) {presenter2.formatted_due_date}

    around do |example|
      Time.use_zone('UTC') { example.run }
    end

    it 'returns a formatted due date' do
      expect(formatted_due_date).to eq 'September 12, 2022'
    end

    it 'returns formatted due date when no enrollment_established_at' do
      expect(formatted_due_date_two). to eq 'August 12, 2022'
    end
  end

  describe '#selected_location_details' do
    subject(:selected_location_details) { presenter.selected_location_details }

    it 'returns a hash of location details associated with the enrollment' do
      expect(selected_location_details).to include(
        'formatted_city_state_zip' => kind_of(String),
        'name' => kind_of(String),
        'phone' => kind_of(String),
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

  describe '#needs_proof_of_address?' do
    subject(:needs_proof_of_address) { presenter.needs_proof_of_address? }

    context 'with current address matching id' do
      let(:current_address_matches_id) { true }

      it { expect(needs_proof_of_address).to eq false }
    end

    context 'with current address not matching id' do
      let(:current_address_matches_id) { false }

      it { expect(needs_proof_of_address).to eq true }
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
