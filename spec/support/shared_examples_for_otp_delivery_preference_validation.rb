shared_examples 'an otp delivery preference form' do
  let(:voice_unsupported_phone) { '242-302-2000' } # A phone number from the Bahamas

  context 'when otp_delivery_preference is voice and phone number does not support voice' do
    let(:params) do
      super().merge(
        phone: '242-302-2000',
        international_code: 'BS',
        otp_delivery_preference: 'voice',
      )
    end

    it 'is invalid' do
      result = subject.submit(params)
      expect(result.success?).to eq(false)
      expect(result.errors[:phone].first).to eq(
        I18n.t(
          'two_factor_authentication.otp_delivery_preference.phone_unsupported',
          location: 'Bahamas',
        ),
      )
    end
  end

  context 'when otp_delivery_preference is not voice or sms' do
    let(:params) { super().merge(otp_delivery_preference: 'foo') }

    it 'is invalid' do
      result = subject.submit(params)

      expect(result.success?).to eq(false)
      expect(result.errors[:otp_delivery_preference]).to_not be_empty
    end
  end

  context 'when otp_delivery_preference is empty' do
    let(:params) { super().merge(otp_delivery_preference: '') }

    it 'is invalid' do
      result = subject.submit(params)

      expect(result.success?).to eq(false)
      expect(result.errors[:otp_delivery_preference]).to_not be_empty
    end
  end

  context 'when otp_delivery_preference param is not present' do
    let(:params) do
      hash = super()
      hash.delete(:otp_delivery_preference)
      hash
    end

    it 'is valid' do
      result = subject.submit(params)

      expect(result.success?).to eq(true)
    end
  end
end
