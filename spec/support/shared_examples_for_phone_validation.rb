shared_examples 'a phone form' do
  describe 'phone presence validation' do
    it 'is invalid when phone is blank' do
      subject.submit(phone: '')

      expect(subject).to_not be_valid
    end
  end

  describe 'phone validation' do
    it 'uses the phony_rails gem with country option set to US' do
      phone_validator = subject._validators.values.flatten.
                        detect { |v| v.class == PhonyPlausibleValidator }

      expect(phone_validator.options).
        to eq(country_code: 'US', presence: true, message: :improbable_phone)
    end
  end

  describe 'phone uniqueness' do
    context 'when phone is already taken' do
      it 'is valid' do
        second_user = build_stubbed(:user, :signed_up, phone: '+1 (202) 555-1213')
        allow(User).to receive(:exists?).with(email: 'new@gmail.com').and_return(false)
        allow(User).to receive(:exists?).with(phone: second_user.phone).and_return(true)

        result = subject.submit(phone: second_user.phone)
        expect(result).to be_kind_of(FormResponse)
        expect(result.success?).to eq(true)
      end
    end

    context 'when phone is not already taken' do
      it 'is valid' do
        result = subject.submit(phone: '+1 (703) 555-1212')
        expect(result).to be_kind_of(FormResponse)
        expect(result.success?).to be true
      end
    end

    context 'when phone is same as current user' do
      it 'is valid' do
        result = subject.submit(phone: user.phone)
        expect(result).to be_kind_of(FormResponse)
        expect(result.success?).to be true
      end
    end
  end

  describe '#submit' do
    it 'formats the phone before assigning it' do
      subject.submit(phone: '703-555-1212')

      expect(subject.phone).to eq '+1 (703) 555-1212'
    end
  end
end
