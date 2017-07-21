require 'shoulda/matchers'

shared_examples 'a phone form' do
  include Shoulda::Matchers::ActiveModel

  describe 'phone presence validation' do
    it 'is invalid when phone is blank' do
      subject.submit(phone: '')

      expect(subject).to_not be_valid
    end
  end

  describe 'phone validation' do
    it 'uses the phony_rails gem' do
      phone_validator = subject._validators.values.flatten.
                        detect { |v| v.class == PhonyPlausibleValidator }

      expect(phone_validator.options[:presence]).to eq(true)
      expect(phone_validator.options[:message]).to eq(:improbable_phone)
      expect(phone_validator.options).to include(:international_code)
    end

    it do
      should validate_inclusion_of(:international_code).
        in_array(PhoneNumberCapabilities::INTERNATIONAL_CODES.keys)
    end

    it 'validates that the number matches the requested international code' do
      result = subject.submit(phone: '123 123 1234', international_code: 'MA')

      expect(result).to be_kind_of(FormResponse)
      expect(result.success?).to eq(false)
      expect(result.errors).to include(:phone)
    end
  end

  describe 'phone uniqueness' do
    context 'when phone is already taken' do
      it 'is valid' do
        second_user = build_stubbed(:user, :signed_up, phone: '+1 (202) 555-1213')
        allow(User).to receive(:exists?).with(email: 'new@gmail.com').and_return(false)
        allow(User).to receive(:exists?).with(phone: second_user.phone).and_return(true)

        result = subject.submit(phone: second_user.phone, international_code: 'US')
        expect(result).to be_kind_of(FormResponse)
        expect(result.success?).to eq(true)
      end
    end

    context 'when phone is not already taken' do
      it 'is valid' do
        result = subject.submit(phone: '+1 (703) 555-1212', international_code: 'US')
        expect(result).to be_kind_of(FormResponse)
        expect(result.success?).to be true
      end
    end

    context 'when phone is same as current user' do
      it 'is valid' do
        result = subject.submit(phone: user.phone, international_code: 'US')
        expect(result).to be_kind_of(FormResponse)
        expect(result.success?).to be true
      end
    end
  end

  describe '#submit' do
    it 'formats the phone before assigning it' do
      subject.submit(phone: '703-555-1212', international_code: 'US')

      expect(subject.phone).to eq '+1 (703) 555-1212'
    end
  end
end
