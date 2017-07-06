require 'rails_helper'

RSpec.describe Idv::VendorResult do
  let(:success) { true }
  let(:errors) { { foo: ['is not valid'] } }
  let(:reasons) { %w[foo bar baz] }
  let(:session_id) { SecureRandom.uuid }
  let(:normalized_applicant) do
    Proofer::Applicant.new(
      last_name: 'Ever',
      first_name: 'Greatest'
    )
  end
  let(:timed_out) { false }

  subject(:vendor_result) do
    Idv::VendorResult.new(
      success: success,
      errors: errors,
      reasons: reasons,
      session_id: session_id,
      normalized_applicant: normalized_applicant,
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
    it 'serializes normalized_applicant correctly' do
      json = vendor_result.to_json

      parsed = JSON.parse(json, symbolize_names: true)
      expect(parsed[:normalized_applicant][:last_name]).to eq(normalized_applicant.last_name)
    end
  end

  describe '.new_from_json' do
    subject(:new_from_json) { Idv::VendorResult.new_from_json(vendor_result.to_json) }

    it 'has simple attributes' do
      expect(new_from_json.success?).to eq(vendor_result.success?)
      expect(new_from_json.errors).to eq(vendor_result.errors)
      expect(new_from_json.reasons).to eq(vendor_result.reasons)
      expect(new_from_json.session_id).to eq(vendor_result.session_id)
    end

    it 'turns applicant into a full object' do
      expect(new_from_json.normalized_applicant.last_name).to eq(normalized_applicant.last_name)
    end

    context 'without an applicant' do
      let(:normalized_applicant) { nil }

      it 'does not have an applicant' do
        expect(new_from_json.normalized_applicant).to eq(nil)
      end
    end
  end
end
