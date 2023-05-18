require 'rails_helper'

RSpec.describe InPerson::EnrollmentsReadyForStatusCheck::UserAnalyticsFactory do
  subject(:user_analytics_factory) { described_class.new }

  describe '#analytics' do
    it 'returns an analytics instance' do
      expect(user_analytics_factory.analytics).to be_instance_of(Analytics)
    end

    it 'uses an anonymous user by default' do
      expect(user_analytics_factory.analytics.user).to be_instance_of(AnonymousUser)
    end

    it 'can accept and use a different user' do
      fake_user = instance_double(User)
      expect(user_analytics_factory.analytics(user: fake_user).user).to be(fake_user)
    end
  end
end
