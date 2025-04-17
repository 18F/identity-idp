require 'rails_helper'
require 'data_requests/local'

RSpec.describe DataRequests::Local::WriteUserInfo do
  describe '#call' do
    let(:io) { StringIO.new }
    let(:csv) { CSV.new(io) }

    subject(:instance) do
      DataRequests::Local::WriteUserInfo.new(
        user_report:,
        csv:,
        include_header: true,
      )
    end

    let(:user_report) do
      JSON.parse(
        File.read('spec/fixtures/data_request.json'), symbolize_names: true
      ).first
    end
    let(:uuid) { user_report[:requesting_issuer_uuid] }

    it 'adds user information to the CSV' do
      instance.call

      parsed = CSV.parse(io.string, headers: true)

      email_row = parsed.find { |r| r['type'] == 'Email' }
      expect(email_row['uuid']).to eq(uuid)
      expect(email_row['value']).to eq('test@example.com')
      expect(email_row['created_at']).to be_present
      expect(email_row['confirmed_at']).to be_present

      phone_row = parsed.find { |r| r['type'] == 'Phone configuration' }
      expect(phone_row['uuid']).to eq(uuid)
      expect(phone_row['value']).to eq('+1 555-555-5555')
      expect(phone_row['created_at']).to be_present
      expect(phone_row['confirmed_at']).to be_present
    end

    context 'with a not_found user' do
      let(:uuid) { SecureRandom.hex }
      let(:user_report) do
        {
          user_id: nil,
          login_uuid: nil,
          requesting_issuer_uuid: uuid,
          email_addresses: [],
          mfa_configurations: {
            phone_configurations: [],
            auth_app_configurations: [],
            webauthn_configurations: [],
            piv_cac_configurations: [],
            backup_code_configurations: [],
          },
          user_events: [],
          not_found: true,
        }
      end

      it 'writes a not found row' do
        instance.call

        parsed = CSV.parse(io.string, headers: true)
        expect(parsed.first['uuid']).to eq(uuid)
        expect(parsed.first['type']).to eq('not found')
      end
    end
  end
end
