require 'rails_helper'

RSpec.describe Idv::VendorResult do
  let(:success) { true }
  let(:errors) { { foo: ['is not valid'] } }
  let(:messages) { %w[foo bar baz] }
  let(:applicant) { { last_name: 'Ever', first_name: 'Greatest' } }
  let(:timed_out) { false }

  subject(:vendor_result) do
    Idv::VendorResult.new(
      success: success,
      errors: errors,
      messages: messages,
      applicant: applicant,
      timed_out: timed_out
    )
  end

  describe '#success?' do
    it 'is the success value' do
      expect(vendor_result.success?).to eq(success)
    end
  end

  describe '#timed_out?' do
    it 'is the timed_out value' do
      expect(vendor_result.timed_out?).to eq(timed_out)
    end
  end

  describe '#to_json' do
    it 'serializes applicant correctly' do
      json = vendor_result.to_json

      parsed = JSON.parse(json, symbolize_names: true)
      expect(parsed[:applicant][:last_name]).to eq(applicant[:last_name])
    end
  end

  describe '.new_from_json' do
    subject(:new_from_json) { Idv::VendorResult.new_from_json(vendor_result.to_json) }

    it 'has simple attributes' do
      expect(new_from_json.success?).to eq(vendor_result.success?)
      expect(new_from_json.errors).to eq(vendor_result.errors)
      expect(new_from_json.messages).to eq(vendor_result.messages)
    end

    it 'turns applicant into a full object' do
      expect(new_from_json.applicant[:last_name]).to eq(applicant[:last_name])
    end

    context 'without an applicant' do
      let(:applicant) { nil }

      it 'does not have an applicant' do
        expect(new_from_json.applicant).to eq(nil)
      end
    end
  end
end
