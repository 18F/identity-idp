require 'rails_helper'

describe PhoneConfigurationDecorator do
  before do
    @user = create(:user, email: 'test1@test.com')
    @phone_config = create(:phone_configuration, user: @user,
                                                 phone: '+1 111 111 1111',
                                                 made_default_at: Time.zone.now)
  end

  describe '#default_number_message' do
    it 'returns the default message for default_phone_configuration' do
      decorator = PhoneConfigurationDecorator.new(@phone_config)

      expect(decorator.default_number_message).to eq t('account.index.default')
    end
  end
end
