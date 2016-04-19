describe SecondFactor, type: :model do
  it 'has a corresponding model for each entry' do
    SecondFactor.all.each do |factor|
      expect("#{factor.name}SecondFactor".constantize.new).to be_truthy
    end
  end

  it 'has Email and Mobile entries' do
    expect(SecondFactor.where(
      'name in (?)',
      %w(Email Mobile)).size).to equal(2)
  end

  describe '#create_authorization' do
    context 'when called on a mobile second factor instance' do
      it 'calls MobileSecondFactor.transmit' do
        user = build_stubbed(:user)
        mobile = build_stubbed(:second_factor, :mobile)

        expect(MobileSecondFactor).to receive(:transmit).with(user)

        mobile.create_authorization(user)
      end
    end

    context 'when called on an email second factor instance' do
      it 'calls EmailSecondFactor.transmit' do
        user = build_stubbed(:user)
        email = build_stubbed(:second_factor, :email)

        expect(EmailSecondFactor).to receive(:transmit).with(user)

        email.create_authorization(user)
      end
    end

    context 'when the user is second_factor_locked' do
      it 'does not call transmit on EmailSecondFactor' do
        user = build_stubbed(:user)
        allow(user).to receive(:second_factor_locked?).and_return(true)

        email = build_stubbed(:second_factor, :email)

        expect(EmailSecondFactor).to_not receive(:transmit).with(user)

        email.create_authorization(user)
      end

      it 'does not call transmit on MobilSecondFactor' do
        user = build_stubbed(:user)
        allow(user).to receive(:second_factor_locked?).and_return(true)

        mobile = build_stubbed(:second_factor, :mobile)

        expect(MobileSecondFactor).to_not receive(:transmit).with(user)

        mobile.create_authorization(user)
      end
    end
  end

  describe '.mobile_id' do
    it 'returns the id of the mobile second factor instance' do
      expect(SecondFactor.mobile_id).
        to eq SecondFactor.find_by_name('Mobile').id
    end
  end
end
