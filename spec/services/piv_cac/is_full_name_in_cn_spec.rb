require 'rails_helper'

describe PivCac::IsFullNameInCn do
  let(:subject) { described_class }

  describe '#call' do
    let(:cn) { 'DOE.JANE.Q.123456' }

    it 'returns true case insensitive and names backwards' do
      results = subject.call(cn, 'Jane', 'Doe')

      expect(results).to eq(true)
    end

    it 'returns false if last is not found' do
      results = subject.call(cn, 'John', 'Doe')

      expect(results).to eq(false)
    end

    it 'returns false if first is not found' do
      results = subject.call(cn, 'Jane', 'Denver')

      expect(results).to eq(false)
    end
  end
end
