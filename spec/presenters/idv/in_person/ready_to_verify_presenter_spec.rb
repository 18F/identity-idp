require 'rails_helper'

RSpec.describe Idv::InPerson::ReadyToVerifyPresenter do
  let(:user) { build(:user) }
  let(:profile) { build(:profile, user: user) }
  let(:enrollment_code) { '2048702198804358' }
  let(:current_address_matches_id) { true }
  let(:created_at) { described_class::USPS_SERVER_TIMEZONE.parse('2022-07-14T00:00:00Z') }
  let(:enrollment) do
    InPersonEnrollment.new(
      user: user,
      profile: profile,
      enrollment_code: enrollment_code,
      created_at: created_at,
      current_address_matches_id: current_address_matches_id,
      selected_location_details:
        JSON.parse(UspsIppFixtures.request_facilities_response)['postOffices'].first,
    )
  end

  subject(:presenter) { described_class.new(enrollment: enrollment) }

  describe '#formatted_due_date' do
    subject(:formatted_due_date) { presenter.formatted_due_date }

    around do |example|
      Time.use_zone('UTC') { example.run }
    end

    it 'returns a formatted due date' do
      expect(formatted_due_date).to eq 'August 12, 2022'
    end
  end

  describe '#selected_location_details' do
    subject(:selected_location_details) { presenter.selected_location_details }

    it 'returns a hash of location details associated with the enrollment' do
      expect(selected_location_details).to include(
        'name' => kind_of(String),
        'streetAddress' => kind_of(String),
        'city' => kind_of(String),
        'state' => kind_of(String),
        'zip5' => kind_of(String),
        'zip4' => kind_of(String),
        'phone' => kind_of(String),
        'hours' => array_including(
          hash_including('weekdayHours' => kind_of(String)),
          hash_including('saturdayHours' => kind_of(String)),
          hash_including('sundayHours' => kind_of(String)),
        ),
      )
    end
  end

  describe '#selected_location_hours' do
    let(:hours_open) { '8:00 AM - 4:30 PM' }
    let(:hours_closed) { 'Closed' }

    before do
      allow(presenter).to receive(:selected_location_details).and_return(
        'hours' => [
          { 'weekdayHours' => hours_open },
          { 'saturdayHours' => hours_open },
          { 'sundayHours' => hours_closed },
        ],
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
end
