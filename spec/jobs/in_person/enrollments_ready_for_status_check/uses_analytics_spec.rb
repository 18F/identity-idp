require 'rails_helper'

RSpec.describe InPerson::EnrollmentsReadyForStatusCheck::UsesAnalytics do
  subject(:uses_analytics) { Class.new.include(described_class).new }

  describe '#analytics' do
    it 'returns an analytics instance' do
      expect(uses_analytics.analytics).to be_instance_of(Analytics)
    end

    it 'uses an anonymous user by default' do
      expect(uses_analytics.analytics.user).to be_instance_of(AnonymousUser)
    end

    it 'can accept and use a different user' do
      fake_user = instance_double(User)
      expect(uses_analytics.analytics(user: fake_user).user).to be(fake_user)
    end
  end
end
