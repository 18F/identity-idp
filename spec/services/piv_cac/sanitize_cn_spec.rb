require 'rails_helper'

describe PivCac::SanitizeCn do
  let(:subject) { described_class }

  describe '#call' do
    let(:cn) { 'Doe.Jane.Q.123456' }
    let(:sanitized_cn) { 'Aaa.Aaaa.A.NNNNNN' }

    it 'returns a sanitized cn' do
      results = subject.call(cn)

      expect(results).to eq(sanitized_cn)
    end
  end
end
