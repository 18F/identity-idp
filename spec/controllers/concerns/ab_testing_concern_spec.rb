require 'rails_helper'

RSpec.describe AbTestingConcern do
  let(:ab_test) do
    AbTest.new(
      experiment_name: 'Test Test',
      buckets: {
        foo: 50,
        bar: 50,
      },
    ) { |user:, **| user.uuid }
  end

  let(:ab_tests) do
    {
      TEST_TEST: ab_test,
    }
  end

  before do
    allow(AbTests).to receive(:all).and_return(ab_tests)
  end

  let(:controller_class) do
    Class.new do
      include AbTestingConcern
      attr_accessor :current_user, :current_sp, :request, :session, :user_session
    end
  end

  let(:user) { build(:user) }

  let(:service_provider) { build(:service_provider) }

  let(:request) { spy }

  let(:session) { {} }

  let(:user_session) { {} }

  subject do
    controller_class.new.tap do |c|
      c.current_user = user
      c.current_sp = service_provider
      c.request = request
      c.session = session
      c.user_session = user_session
    end
  end

  describe '#ab_test_bucket' do
    it 'returns a bucket' do
      expect(ab_test).to receive(:bucket).with(
        user:,
        request:,
        service_provider: service_provider.issuer,
        session:,
        user_session:,
      ).and_call_original

      expect(subject.ab_test_bucket(:TEST_TEST)).to eql(:foo).or(eql(:bar))
    end

    context 'for a non-existant test' do
      it 'raises a RuntimeError' do
        expect do
          subject.ab_test_bucket(:NOT_A_REAL_TEST)
        end.to raise_error RuntimeError, 'Unknown A/B test: NOT_A_REAL_TEST'
      end
    end

    context 'with user keyword argument' do
      let(:other_user) { build(:user) }

      it 'returns bucket determined using given user' do
        expect(ab_test).to receive(:bucket).with(
          user: other_user,
          request:,
          service_provider: service_provider.issuer,
          session:,
          user_session:,
        ).and_call_original

        subject.ab_test_bucket(:TEST_TEST, user: other_user)
      end
    end
  end
end
