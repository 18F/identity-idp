require 'shoulda/matchers'

shared_examples_for 'a phone form' do
  describe 'phone presence validation' do
    it 'is invalid when phone is blank' do
      params[:phone] = ''
      subject.submit(params)

      expect(subject).to_not be_valid
    end
  end

  describe 'phone uniqueness' do
    context 'when phone is already taken' do
      it 'is valid' do
        second_user = build_stubbed(:user, :signed_up, with: { phone: '+1 (202) 555-1213' })
        allow(User).to receive(:exists?).with(email: 'new@gmail.com').and_return(false)
        allow(User).to receive(:exists?).with(
          phone_configuration: {
            phone: MfaContext.new(second_user).phone_configurations.first.phone,
          },
        ).and_return(true)

        params[:phone] = MfaContext.new(second_user).phone_configurations.first.phone

        result = subject.submit(params)
        expect(result).to be_kind_of(FormResponse)
        expect(result.success?).to eq(true)
      end
    end

    context 'when phone is not already taken' do
      it 'is valid' do
        result = subject.submit(params)
        expect(result).to be_kind_of(FormResponse)
        expect(result.success?).to be true
      end
    end

    context 'when phone is same as current user' do
      it 'is valid' do
        MfaContext.new(user).phone_configurations.first.phone = '+1 (703) 500-5000'
        params[:phone] = MfaContext.new(user).phone_configurations.first.phone
        result = subject.submit(params)

        expect(result).to be_kind_of(FormResponse)
        expect(result.success?).to be true
      end
    end
  end

  describe '#submit' do
    it 'formats the phone before assigning it' do
      params[:phone] = '(703) 555-1212'
      subject.submit(params)

      expect(subject.phone).to eq '+1 703-555-1212'
    end
  end
end

shared_examples_for 'an international phone form' do
  it 'validates that the number matches the requested international code' do
    params[:phone] = '123 123 1234'
    params[:international_code] = 'MA'
    result = subject.submit(params)

    expect(result).to be_kind_of(FormResponse)
    expect(result.success?).to eq(false)
    expect(result.errors).to include(:phone)
  end

  context 'when otp_delivery_preference is voice and phone number does not support voice' do
    # 242 is the area code for the bahamas which does not support voice calls
    let(:unsupported_phone) { '242-327-0143' }
    let(:params) do
      {
        phone: unsupported_phone,
        international_code: 'US',
        otp_delivery_preference: 'voice',
      }
    end

    it 'is invalid' do
      result = subject.submit(params)

      expect(result.success?).to eq(false)
    end
  end

  it 'does not raise inclusion errors for Norwegian phone numbers' do
    # ref: https://github.com/18F/identity-private/issues/2392
    params[:phone] = '21 11 11 11'
    params[:international_code] = 'NO'
    result = subject.submit(params)

    expect(result).to be_kind_of(FormResponse)
    expect(result.success?).to eq(true)
    expect(result.errors).to be_empty
  end

  it 'preserves the format of the submitted phone number if phone is invalid' do
    params[:phone] = '555-555-5000'
    params[:international_code] = 'MA'

    result = subject.submit(params)

    expect(result.success?).to eq(false)
    expect(subject.phone).to eq('555-555-5000')
  end
end
