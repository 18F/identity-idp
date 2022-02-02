require 'rails_helper'

RSpec.describe Telephony::Pinpoint::OptOutManager do
  include_context 'telephony'

  subject(:opt_out_manager) { Telephony::Pinpoint::OptOutManager.new }

  let(:phone_number) { Faker::PhoneNumber.cell_phone }

  before do
    allow(opt_out_manager).to receive(:build_client).
      and_return(first_client, second_client)
  end

  let(:first_client) { Aws::SNS::Client.new(stub_responses: true) }
  let(:second_client) { Aws::SNS::Client.new(stub_responses: true) }

  describe '#opt_in_phone_number' do
    subject(:opt_in) { opt_out_manager.opt_in_phone_number(phone_number) }

    context 'when opting in is successful' do
      before do
        first_client.stub_responses(:opt_in_phone_number, {})
        first_client.stub_responses(:check_if_phone_number_is_opted_out, is_opted_out: false)
      end

      it 'has a successful response' do
        expect(opt_in.success?).to eq(true)
        expect(opt_in.error).to be_nil
      end
    end

    context 'when opting in is not successful (already opted in w/in last 30 days)' do
      before do
        first_client.stub_responses(:opt_in_phone_number, {})
        first_client.stub_responses(:check_if_phone_number_is_opted_out, is_opted_out: true)
      end

      it 'returns a response that is unsuccessful, but has no error' do
        expect(opt_in.success?).to eq(false)
        expect(opt_in.error).to be_nil
      end
    end

    context 'when there is a network error' do
      before do
        first_client.stub_responses(
          :check_if_phone_number_is_opted_out,
          'InternalServerErrorException',
        )
      end

      it 'is an unsuccessful response with an error' do
        expect(opt_in.success?).to eq(false)
        expect(opt_in.error).to be_present
      end

      context 'success in the backup region' do
        before do
          Telephony.config.pinpoint.add_sms_config do |sms|
            sms.region = 'backup-sms-region'
            sms.access_key_id = 'fake-pnpoint-access-key-id-sms'
            sms.secret_access_key = 'fake-pinpoint-secret-access-key-sms'
            sms.application_id = 'backup-sms-application-id'
          end

          second_client.stub_responses(:opt_in_phone_number, {})
          second_client.stub_responses(
            :check_if_phone_number_is_opted_out,
            is_opted_out: false,
          )
        end

        it 'fails over to the backup region and succeeds' do
          expect(Telephony::Pinpoint::PinpointHelper).to receive(:notify_pinpoint_failover)

          expect(opt_in.success?).to eq(true)
          expect(opt_in.error).to be_nil
        end
      end
    end
  end
end
