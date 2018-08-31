require 'shoulda/matchers'

shared_examples 'a phone form' do
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
          phone_configuration: { phone: second_user.phone_configuration.phone }
        ).and_return(true)

        params[:phone] = second_user.phone_configuration.phone

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
        user.phone_configuration.phone = '+1 (703) 500-5000'
        params[:phone] = user.phone_configuration.phone
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
