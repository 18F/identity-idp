shared_examples 'an otp delivery preference form' do
  describe 'voice delivery validation' do
    it 'is valid when voice is supported for the phone' do
      params[:phone] = '225-555-5000'
      params[:otp_delivery_preference] = 'voice'

      result = subject.submit(params)

      expect(result.success?).to eq(true)
    end

    it 'is invalid when voice is unsupported for the phone' do
      # 242 is the area code for the bahamas which does not support voice calls
      params[:phone] = '242-327-0143'
      params[:otp_delivery_preference] = 'voice'

      result = subject.submit(params)

      expect(result.success?).to eq(false)
      expect(result.errors).to include(:phone)
    end
  end

  context 'when otp_delivery_preference is sms' do
    it 'is valid' do
      params[:otp_delivery_preference] = 'sms'

      result = subject.submit(params)

      expect(result.success?).to eq(true)
    end
  end

  context 'when otp_delivery_preference is voice' do
    it 'is valid' do
      params[:otp_delivery_preference] = 'voice'

      result = subject.submit(params)

      expect(result.success?).to eq(true)
    end
  end

  context 'when otp_delivery_preference is not voice or sms' do
    it 'is invalid' do
      params[:otp_delivery_preference] = 'foo'

      result = subject.submit(params)

      expect(result.success?).to eq(false)
      expect(result.errors[:otp_delivery_preference].first).
        to eq 'is not included in the list'
    end
  end

  context 'when otp_delivery_preference is empty' do
    it 'is invalid' do
      params[:otp_delivery_preference] = ''
      result = subject.submit(params)

      expect(result.success?).to eq(false)
      expect(result.errors[:otp_delivery_preference].first).
        to eq 'is not included in the list'
    end
  end
end
