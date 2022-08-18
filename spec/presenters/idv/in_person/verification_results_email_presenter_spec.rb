require 'rails_helper'

RSpec.describe Idv::InPerson::VerificationResultsEmailPresenter do
  let(:location_name) { 'FRIENDSHIP' }
  let(:status_updated_at) { described_class::USPS_SERVER_TIMEZONE.parse('2022-07-14T00:00:00Z') }
  let!(:enrollment) do
    create(
      :in_person_enrollment,
      :pending,
      selected_location_details: { name: location_name },
    )
  end

  subject(:presenter) { described_class.new(enrollment: enrollment) }

  describe '#location_name' do
    it 'returns the enrollment location name' do
      expect(presenter.location_name).to eq(location_name)
    end
  end

  describe '#formatted_verified_date' do
    around do |example|
      Time.use_zone('UTC') { example.run }
    end

    it 'returns a formatted verified date' do
      enrollment.update(status_updated_at: status_updated_at)
      expect(presenter.formatted_verified_date).to eq 'July 13, 2022'
    end
  end
end
