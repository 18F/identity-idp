require 'rails_helper'

RSpec.describe Idv::InPerson::AddressForm do
  let(:pii) { Idp::Constants::MOCK_IDV_APPLICANT_STATE_ID_ADDRESS }
  context 'test validation for transliteration after form submission' do
    let(:good_params) do
      {
        address1: Faker::Address.street_address,
        address2: Faker::Address.secondary_address,
        zipcode: Faker::Address.zip_code,
        state: Faker::Address.state_abbr,
        city: Faker::Address.city,
      }
    end
    let(:invalid_char) { '$' }
    let(:bad_params) do
      {
        address1: invalid_char + Faker::Address.street_address,
        address2: invalid_char + Faker::Address.secondary_address + invalid_char,
        zipcode: Faker::Address.zip_code,
        state: Faker::Address.state_abbr,
        city: invalid_char + Faker::Address.city,
      }
    end
    let(:subject) { described_class.new }

    it 'submit success with good params' do
      good_params[:same_address_as_id] = true
      result = subject.submit(good_params)
      expect(subject.errors.empty?).to be(true)
      expect(result).to be_kind_of(FormResponse)
      expect(result.success?).to be(true)
    end

    it 'submit failure with bad params' do
      bad_params[:same_address_as_id] = false
      result = subject.submit(bad_params)
      expect(subject.errors.empty?).to be(false)
      expect(subject.errors.to_hash).to include(:address1, :address2, :city)
      expect(result).to be_kind_of(FormResponse)
      expect(result.success?).to be(false)
      expect(result.errors.empty?).to be(true)
    end

    it 'submit with missing same_address_as_id should be successful' do
      missing_required_params = good_params.except(:same_address_as_id)
      result = subject.submit(missing_required_params)
      expect(subject.errors).to be_empty
      expect(result).to be_kind_of(FormResponse)
      expect(result.success?).to be(true)
    end
  end
end
