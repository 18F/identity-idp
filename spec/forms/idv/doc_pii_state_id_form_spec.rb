require 'rails_helper'

RSpec.describe Idv::DocPiiStateIdForm do
  let(:user) { create(:user) }
  let(:subject) { Idv::DocPiiStateIdForm.new(pii: pii) }
  let(:valid_state_id_expiration) { Time.zone.today.to_s }
  let(:good_pii) do
    {
      address1: Faker::Address.street_address,
      zipcode: Faker::Address.zip_code,
      state: Faker::Address.state_abbr,
      state_id_jurisdiction: 'AL',
      state_id_number: 'S59397998',
      state_id_issued: '2024-01-01',
      state_id_expiration: valid_state_id_expiration,
    }
  end
  let(:state_id_expired_error_pii) do
    {
      address1: Faker::Address.street_address,
      zipcode: Faker::Address.zip_code,
      state: Faker::Address.state_abbr,
      state_id_jurisdiction: 'AL',
      state_id_number: 'S59397998',
      state_id_issued: '2024-01-01',
      state_id_expiration: '2024-07-25',
    }
  end
  let(:state_id_expiration_error_pii) do
    {
      address1: Faker::Address.street_address,
      zipcode: Faker::Address.zip_code,
      state: Faker::Address.state_abbr,
      state_id_jurisdiction: 'AL',
      state_id_number: 'S59397998',
      state_id_issued: '2024-01-01',
      state_id_expiration: nil,
    }
  end
  let(:non_string_zipcode_pii) do
    {
      address1: Faker::Address.street_address,
      state: Faker::Address.state_abbr,
      zipcode: 12345,
      state_id_jurisdiction: 'AL',
      state_id_number: 'S59397998',
      state_id_expiration: valid_state_id_expiration,
    }
  end
  let(:nil_zipcode_pii) do
    {
      address1: Faker::Address.street_address,
      state: Faker::Address.state_abbr,
      zipcode: nil,
      state_id_jurisdiction: 'AL',
      state_id_number: 'S59397998',
      state_id_expiration: valid_state_id_expiration,
    }
  end
  let(:state_error_pii) do
    {
      address1: Faker::Address.street_address,
      zipcode: Faker::Address.zip_code,
      state: 'YORK',
      state_id_jurisdiction: 'AL',
      state_id_number: 'S59397998',
      state_id_expiration: valid_state_id_expiration,
    }
  end
  let(:jurisdiction_error_pii) do
    {
      address1: Faker::Address.street_address,
      zipcode: Faker::Address.zip_code,
      state: Faker::Address.state_abbr,
      state_id_jurisdiction: 'XX',
      state_id_number: 'S59397998',
      state_id_expiration: valid_state_id_expiration,
    }
  end
  let(:address1_error_pii) do
    {
      address1: nil,
      zipcode: Faker::Address.zip_code,
      state: Faker::Address.state_abbr,
      state_id_jurisdiction: 'AL',
      state_id_number: 'S59397998',
      state_id_expiration: valid_state_id_expiration,
    }
  end
  let(:nil_state_id_number_pii) do
    {
      address1: nil,
      zipcode: Faker::Address.zip_code,
      state: Faker::Address.state_abbr,
      state_id_jurisdiction: 'AL',
      state_id_number: nil,
      state_id_expiration: valid_state_id_expiration,
    }
  end
  let(:pii) { nil }
end
