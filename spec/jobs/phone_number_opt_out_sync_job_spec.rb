require 'rails_helper'

RSpec.describe PhoneNumberOptOutSyncJob do
  describe '#perform' do
    include_context 'telephony'

    let(:phone1) { Faker::PhoneNumber.cell_phone }
    let(:phone2) { Faker::PhoneNumber.cell_phone }
    let(:phone3) { Faker::PhoneNumber.cell_phone }

    before do
      Aws.config[:sns] = {
        stub_responses: {
          list_phone_numbers_opted_out: [
            {
              phone_numbers: [phone1, phone2],
              next_token: SecureRandom.hex,
            },
            {
              phone_numbers: [phone3],
            },
          ],
        },
      }
    end

    it 'adds phone numbers that are opted out in AWS to the database' do
      PhoneNumberOptOutSyncJob.new.perform(Time.zone.now)

      [phone1, phone2, phone3].each do |phone|
        expect(PhoneNumberOptOut.find_with_phone(phone)).to be_present
      end
    end
  end
end
