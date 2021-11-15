describe Telephony::Test::Call do
  let(:body) { 'The code is 1, 2, 3, 4, 5, 6' }
  let(:otp) { '123456' }

  subject { described_class.new(to: '+1 (555) 555-5000', body: body, otp: otp) }

  describe '#otp' do
    context 'the call contains an OTP' do
      it 'returns the OTP' do
        expect(subject.otp).to eq('123456')
      end
    end

    context 'the call does not contain an OTP' do
      let(:body) { 'this is a plain old alert' }
      let(:otp) { nil }

      it 'returns nil' do
        expect(subject.otp).to eq(nil)
      end
    end
  end

  describe '.last_otp' do
    before do
      described_class.clear_calls
      [
        described_class.new(
          to: '+1 (555) 1111',
          body: 'A, B, C, 1, 2, 3 is the code',
          otp: 'ABC123',
        ),
        described_class.new(
          to: '+1 (555) 2222',
          body: 'A, B, C, D, E, F is the code',
          otp: 'ABCDEF',
        ),
        described_class.new(
          to: '+1 (555) 5000',
          body: '1, 1, 1, 1, 1, 1 is the code',
          otp: '111111',
        ),
        described_class.new(
          to: '+1 (555) 5000',
          body: '2, 2, 2, 2, 2, 2 is the code',
          otp: '222222',
        ),
        described_class.new(
          to: '+1 (555) 5000',
          body: 'plain alert',
          otp: nil,
        ),
        described_class.new(
          to: '+1 (555) 4000',
          body: '3, 3, 3, 3, 3, 3 is the code',
          otp: '333333',
        ),
        described_class.new(
          to: '+1 (555) 4000',
          body: 'plain alert',
          otp: nil,
        ),
      ].each do |call|
        described_class.calls.push(call)
      end
    end

    context 'with a phone number' do
      it 'returns the most recent OTP for that phone number' do
        result = described_class.last_otp(phone: '+1 (555) 5000')

        expect(result).to eq('222222')
      end
    end

    context 'without a phone number' do
      it 'returns the most recent OTP for any phone number' do
        result = described_class.last_otp

        expect(result).to eq('333333')
      end
    end

    context 'when there have been no calls' do
      it 'returns nil' do
        described_class.clear_calls

        expect(described_class.last_otp).to eq(nil)
      end
    end

    context 'with alphanumeric OTPs' do
      it 'returns the most recent ones' do
        expect(described_class.last_otp(phone: '+1 (555) 1111')).to eq('ABC123')
        expect(described_class.last_otp(phone: '+1 (555) 2222')).to eq('ABCDEF')
      end
    end
  end
end
