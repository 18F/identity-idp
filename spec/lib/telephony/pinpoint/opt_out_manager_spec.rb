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
      end

      context 'when the number is no longer opted out' do
        before do
          first_client.stub_responses(:check_if_phone_number_is_opted_out, is_opted_out: false)
        end

        it 'has a successful response' do
          expect(opt_in.success?).to eq(true)
        end
      end

      context 'when the number is still opted out' do
        before do
          first_client.stub_responses(:check_if_phone_number_is_opted_out, is_opted_out: true)
        end

        it 'has an unsuccessful response' do
          expect(opt_in.success?).to eq(false)
        end
      end

      context 'when there is a network error checking opted out' do
        before do
          first_client.stub_responses(
            :check_if_phone_number_is_opted_out,
            'InternalServerErrorException'
          )
        end

        it 'has an error response' do
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

            second_client.stub_responses(
              :opt_in_phone_number,
              {}
            )
            second_client.stub_responses(
              :check_if_phone_number_is_opted_out,
              is_opted_out: false,
            )
          end

          it 'fails over to the backup region and succeeds' do
            expect(Telephony::Pinpoint::PinpointHelper).to receive(:notify_pinpoint_failover)

            expect(opt_in.success?).to eq(true)
          end
        end
      end
    end

    context 'when opting in is not successful' do
      before do
        first_client.stub_responses(:opt_in_phone_number, 'InternalServerErrorException')
      end

      it 'has an unsuccessful response' do
        expect(opt_in.success?).to eq(false)
      end
    end

    context 'when opting in has a network error' do
      before do
        first_client.stub_responses(:opt_in_phone_number, 'InternalServerErrorException')
      end

      it 'has an error response' do
        expect(opt_in.success?).to eq(false)
        expect(opt_in.error).to be_present
      end
    end
  end
end
