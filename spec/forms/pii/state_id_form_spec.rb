require 'rails_helper'

RSpec.describe Pii::StateIdForm do
  let(:valid_state_id) do
    {
      document_number: 'D1234567',
      jurisdiction: 'CA',
      expiration_date: (Time.zone.today + 365).to_s,
      issue_date: '2020-01-01',
      address1: '1 Main St',
      address2: 'Apt 2',
      city: 'Anytown',
      state: 'CA',
      zip_code: '94110',
    }
  end

  subject(:form) { described_class.new(state_id: state_id) }

  context 'with a valid state id' do
    let(:state_id) { valid_state_id }

    it 'is valid' do
      expect(form).to be_valid
    end
  end

  context 'with missing required state-id fields' do
    let(:state_id) do
      valid_state_id.merge(
        document_number: nil,
        jurisdiction: nil,
      )
    end

    it 'reports each missing field' do
      form.valid?
      expect(form.errors[:document_number]).to include('cannot be blank')
      expect(form.errors[:jurisdiction]).to include('cannot be blank')
    end
  end

  context 'with missing expiration and issue dates' do
    let(:state_id) { valid_state_id.merge(expiration_date: nil, issue_date: nil) }

    it 'is valid (expiration and issue dates are optional)' do
      expect(form).to be_valid
    end
  end

  context 'with an invalid jurisdiction' do
    let(:state_id) { valid_state_id.merge(jurisdiction: 'ZZ') }

    it 'reports an inclusion error on jurisdiction' do
      form.valid?
      expect(form.errors[:jurisdiction]).to include('is not a valid state code')
    end
  end

  context 'with an expired state id' do
    let(:state_id) { valid_state_id.merge(expiration_date: (Time.zone.today - 1).to_s) }

    it 'reports expiration error' do
      form.valid?
      expect(form.errors[:expiration_date]).to include('is expired, or near expiration')
    end
  end

  it 'also runs address validations' do
    state_id = valid_state_id.merge(zip_code: 'abc', state: 'ZZ', address1: nil)
    f = described_class.new(state_id: state_id)
    f.valid?
    expect(f.errors[:zip_code]).to be_present
    expect(f.errors[:state]).to include('is not a valid state code')
    expect(f.errors[:address1]).to include('cannot be blank')
  end

  context 'with address fields that exceed the USPS length limit' do
    let(:state_id) { valid_state_id.merge(address1: 'a' * 256, city: 'c' * 256) }

    it 'reports length errors' do
      form.valid?
      expect(form.errors[:address1]).to be_present
      expect(form.errors[:city]).to be_present
    end
  end

  context 'with address fields that contain non-transliterable characters' do
    let(:state_id) { valid_state_id.merge(address1: '1 Main St!', city: 'Bad$City') }

    it 'reports transliterable errors' do
      form.valid?
      expect(form.errors[:address1].join).to match(/has invalid characters/)
      expect(form.errors[:city].join).to match(/has invalid characters/)
    end
  end
end
