require 'rails_helper'

RSpec.describe PhoneNumberOptOut do
  let(:phone) { Faker::PhoneNumber.cell_phone }

  describe '.create_or_find_by_phone' do
    it 'creates a record for the phone' do
      row = nil

      expect do
        row = PhoneNumberOptOut.create_or_find_with_phone(phone)
      end.to change { PhoneNumberOptOut.count }.by(1)

      expect(row.encrypted_phone).to be_present
      expect(row.phone_fingerprint).to eq(
        Pii::Fingerprinter.fingerprint(PhoneNumberOptOut.normalize(phone)),
      )
      expect(row.uuid).to be_present
    end

    it 'returns an existing row if there already is one' do
      first = PhoneNumberOptOut.create_or_find_with_phone(phone)
      second = PhoneNumberOptOut.create_or_find_with_phone(phone)

      expect(first.id).to eq(second.id)
    end

    it 'normalizes phone numbers when creating' do
      spaces = '+1 888 867 5309'
      dashes = '+1-888-867-5309'

      expect(PhoneNumberOptOut.create_or_find_with_phone(spaces).id)
        .to eq(PhoneNumberOptOut.create_or_find_with_phone(dashes).id)
    end
  end

  describe '.find_with_phone' do
    it 'is nil when the row does not exist' do
      expect(PhoneNumberOptOut.find_with_phone(Faker::PhoneNumber.cell_phone)).to be_nil
    end

    it 'is the row when it exists' do
      created = PhoneNumberOptOut.create_or_find_with_phone(phone)
      found = PhoneNumberOptOut.find_with_phone(phone)

      expect(found.id).to eq(created.id)
    end
  end

  describe '#formatted_phone' do
    it 'formats the phone internationally' do
      unformatted = '1 (888) 867-5309'

      expect(PhoneNumberOptOut.create_or_find_with_phone(unformatted).formatted_phone)
        .to eq('+1 888-867-5309')
    end
  end

  describe '#opt_in' do
    it 'deletes the row' do
      row = PhoneNumberOptOut.create_or_find_with_phone(phone)

      expect { row.opt_in }.to change { PhoneNumberOptOut.count }.by(-1)

      expect(PhoneNumberOptOut.find_with_phone(phone)).to be_nil
    end
  end

  describe '#to_param' do
    it 'is the uuid' do
      row = PhoneNumberOptOut.create_or_find_with_phone(phone)

      expect(row.to_param).to eq(row.uuid)
    end
  end
end
