describe Telephony::Response do
  context 'for a successful response' do
    subject { described_class.new(success: true, extra: { test: '1234' }) }

    it 'is successful' do
      expect(subject.success?).to eq(true)
    end

    it 'returns an empty errors hash' do
      expect(subject.errors).to eq({})
    end

    it 'can be serialized into a hash' do
      hash = subject.to_h

      expect(hash).to eq(
        success: true,
        errors: {},
        test: '1234',
      )
    end
  end

  context 'for a failed response' do
    let(:error) { StandardError.new('hello') }
    subject { described_class.new(success: false, error: error, extra: { test: '1234' }) }

    it 'is not successful' do
      expect(subject.success?).to eq(false)
    end

    it 'returns an errors hash' do
      expect(subject.errors).to eq(
        telephony: 'StandardError - hello',
      )
    end

    it 'can be serialized into a hash' do
      hash = subject.to_h

      expect(hash).to eq(
        success: false,
        errors: { telephony: 'StandardError - hello' },
        test: '1234',
      )
    end
  end
end
