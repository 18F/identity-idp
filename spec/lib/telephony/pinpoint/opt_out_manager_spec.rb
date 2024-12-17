require 'rails_helper'

RSpec.describe Telephony::Pinpoint::OptOutManager do
  include_context 'telephony'

  subject(:opt_out_manager) { Telephony::Pinpoint::OptOutManager.new }

  let(:phone_number) { Faker::PhoneNumber.cell_phone }

  before do
    allow(opt_out_manager).to receive(:build_client)
      .and_return(first_client, second_client)
  end

  let(:first_client) { Aws::SNS::Client.new(stub_responses: true) }
  let(:second_client) { Aws::SNS::Client.new(stub_responses: true) }

  def add_second_region_config
    Telephony.config.pinpoint.add_sms_config do |sms|
      sms.region = 'backup-sms-region'
      sms.access_key_id = 'fake-pnpoint-access-key-id-sms'
      sms.secret_access_key = 'fake-pinpoint-secret-access-key-sms'
      sms.application_id = 'backup-sms-application-id'
    end
  end

  describe '#opt_in_phone_number' do
    subject(:opt_in) { opt_out_manager.opt_in_phone_number(phone_number) }

    before do
      add_second_region_config
    end

    context 'when opting in is successful in all regions' do
      before do
        first_client.stub_responses(:opt_in_phone_number, {})
        second_client.stub_responses(:opt_in_phone_number, {})
      end

      it 'has a successful response' do
        expect(opt_in.success?).to eq(true)
        expect(opt_in.error).to be_nil
      end
    end

    context 'when opting in is not successful in one region (already opted in w/in last 30 days)' do
      before do
        first_client.stub_responses(
          :opt_in_phone_number,
          'InvalidParameter',
          'Invalid parameter: Cannot opt in right now, latest opt in is too recent',
        )
        second_client.stub_responses(:opt_in_phone_number, {})
      end

      it 'returns a response that is unsuccessful, but has no error' do
        expect(opt_in.success?).to eq(false)
        expect(opt_in.error).to be_nil
      end
    end

    context 'when there is a network error in one region' do
      before do
        first_client.stub_responses(:opt_in_phone_number, {})
        second_client.stub_responses(
          :opt_in_phone_number,
          'InternalServerErrorException',
        )
      end

      it 'returns an unsuccessful response with an error' do
        expect(opt_in.success?).to eq(false)
        expect(opt_in.error).to be_present
      end
    end

    context 'with no region configs' do
      before do
        Telephony.config.pinpoint.sms_configs.clear
      end

      it 'is an unsuccessful response' do
        expect(opt_in.success?).to eq(false)
      end
    end
  end

  describe '#opted_out_numbers' do
    let(:phone1) { Faker::PhoneNumber.cell_phone }
    let(:phone2) { Faker::PhoneNumber.cell_phone }
    let(:phone3) { Faker::PhoneNumber.cell_phone }
    let(:phone4) { Faker::PhoneNumber.cell_phone }
    let(:phone5) { Faker::PhoneNumber.cell_phone }
    let(:phone6) { Faker::PhoneNumber.cell_phone }

    before do
      add_second_region_config

      first_client.stub_responses(
        :list_phone_numbers_opted_out,
        [
          {
            phone_numbers: [phone1, phone2],
            next_token: SecureRandom.hex,
          },
          {
            phone_numbers: [phone3],
          },
        ],
      )
      second_client.stub_responses(
        :list_phone_numbers_opted_out,
        [
          {
            phone_numbers: [phone4, phone5],
            next_token: SecureRandom.hex,
          },
          {
            phone_numbers: [phone6],
          },
        ],
      )
    end

    it 'iterates phone numbers across regions' do
      expect(opt_out_manager.opted_out_numbers.to_a)
        .to eq([phone1, phone2, phone3, phone4, phone5, phone6])
    end
  end
end
