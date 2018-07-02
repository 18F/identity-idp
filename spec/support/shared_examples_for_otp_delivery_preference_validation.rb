shared_examples 'an otp delivery preference form' do
  let(:phone) { '+1 (703) 555-5000' }
  let(:params) do
    {
      phone: phone,
      otp_delivery_preference: 'voice',
      international_code: 'US',
    }
  end

  context 'voice' do
    it 'is valid when supported for the phone' do
      update_user = instance_double(UpdateUser)
      attributes = { otp_delivery_preference: 'voice' }
      allow(UpdateUser).to receive(:new).with(user: user, attributes: attributes).
        and_return(update_user)
      expect(update_user).to receive(:call)

      capabilities = spy(PhoneNumberCapabilities)
      allow(PhoneNumberCapabilities).to receive(:new).with(phone).and_return(capabilities)
      allow(capabilities).to receive(:sms_only?).and_return(false)

      result = subject.submit(params)

      expect(result.success?).to eq(true)
    end

    it 'is invalid when unsupported for the phone' do
      update_user = instance_double(UpdateUser)
      attributes = { otp_delivery_preference: 'voice' }
      allow(UpdateUser).to receive(:new).with(user: user, attributes: attributes).
        and_return(update_user)
      expect(update_user).to_not receive(:call)

      capabilities = spy(PhoneNumberCapabilities)
      allow(PhoneNumberCapabilities).to receive(:new).with(phone).and_return(capabilities)
      allow(capabilities).to receive(:sms_only?).and_return(true)

      result = subject.submit(params)

      expect(result.success?).to eq(false)
      expect(result.errors).to include(:phone)
    end
  end
end
