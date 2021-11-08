describe Telephony::Test::Message do
  let(:body) { 'The code is 123456' }
  let(:otp) { '123456' }

  subject { described_class.new(to: '+1 (555) 555-5000', body: body, otp: otp) }

  describe '#otp' do
    context 'the message contains an OTP' do
      it 'returns the OTP' do
        expect(subject.otp).to eq('123456')
      end
    end

    context 'the message does not contain an OTP' do
      let(:body) { 'this is a plain old alert' }
      let(:otp) { nil }

      it 'returns nil' do
        expect(subject.otp).to eq(nil)
      end
    end
  end

  describe '.last_otp' do
    before do
      described_class.clear_messages
      [
        described_class.new(to: '+1 (555) 1111', body: 'ABC123 is the code', otp: 'ABC123'),
        described_class.new(to: '+1 (555) 2222', body: 'ABCDEF is the code', otp: 'ABCDEF'),
        described_class.new(to: '+1 (555) 5000', body: '111111 is the code', otp: '111111'),
        described_class.new(to: '+1 (555) 5000', body: '222222 is the code', otp: '222222'),
        described_class.new(to: '+1 (555) 5000', body: 'plain alert', otp: nil),
        described_class.new(to: '+1 (555) 4000', body: '333333 is the code', otp: '333333'),
        described_class.new(to: '+1 (555) 4000', body: 'plain alert', otp: nil),
      ].each do |message|
        described_class.messages.push(message)
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

    context 'when there have been no messages' do
      it 'returns nil' do
        described_class.clear_messages

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
