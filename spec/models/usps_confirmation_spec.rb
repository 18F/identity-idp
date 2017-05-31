require 'rails_helper'

describe UspsConfirmation do
  describe '#decrypted_entry' do
    it 'returns plain entry' do
      usps_confirmation = subject
      usps_confirmation.entry = UspsConfirmationEntry.new_from_hash(otp: 123).encrypted

      plain_entry = usps_confirmation.decrypted_entry

      expect(plain_entry.otp).to eq 123
    end
  end
end
