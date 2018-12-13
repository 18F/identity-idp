require 'rails_helper'

describe Idv::Utils::PiiFromDoc do
  include DocAuthHelper

  let(:subject) { Idv::Utils::PiiFromDoc }
  let(:ssn) { '123' }
  let(:phone) { '456' }

  describe '#call' do
    it 'correctly parses the pii data from acuant and returns a hash' do
      results = subject.new(DocAuthHelper::ACUANT_RESULTS).call(phone)
      results[:ssn] = ssn
      expect(results).to eq(DocAuthHelper::ACUANT_RESULTS_TO_PII)
    end
  end
end
