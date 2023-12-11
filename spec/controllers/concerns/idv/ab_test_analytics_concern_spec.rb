require 'rails_helper'

RSpec.describe Idv::AbTestAnalyticsConcern do
  let(:user) { create(:user) }
  let(:idv_session) do
    Idv::Session.new(user_session: subject.user_session, current_user: user, service_provider: nil)
  end

  describe '#ab_test_analytics_buckets' do
    controller(ApplicationController) do
      include Idv::AbTestAnalyticsConcern
    end

    let(:acuant_sdk_args) { { as_bucket: :as_value } }
    let(:instant_verify_sdk_args) { { iv_bucket: :iv_value } }

    before do
      allow(subject).to receive(:current_user).and_return(user)
      expect(subject).to receive(:acuant_sdk_ab_test_analytics_args).
        and_return(acuant_sdk_args)
      expect(subject).to receive(:lexisnexis_instant_verify_workflow_ab_test_analytics_args).
        and_return(instant_verify_sdk_args)
    end

    context 'idv_session is available' do
      before do
        sign_in(user)
        expect(subject).to receive(:idv_session).once.and_return(idv_session)
      end

      it 'includes acuant_sdk_ab_test_analytics_args' do
        expect(controller.ab_test_analytics_buckets).to include(acuant_sdk_args)
      end

      it 'includes lexisnexis_instant_verify_sdk_ab_test_analytics_args' do
        expect(controller.ab_test_analytics_buckets).to include(instant_verify_sdk_args)
      end

      it 'includes skip_hybrid_handoff' do
        idv_session.skip_hybrid_handoff = :shh_value
        expect(controller.ab_test_analytics_buckets).to include({ skip_hybrid_handoff: :shh_value })
      end
    end

    context 'idv_session is not available' do
      it 'still includes acuant_sdk_ab_test_analytics_args' do
        expect(controller.ab_test_analytics_buckets).to include(acuant_sdk_args)
      end

      it 'still includes lexisnexis_instant_verify_sdk_ab_test_analytics_args' do
        expect(controller.ab_test_analytics_buckets).to include(instant_verify_sdk_args)
      end
    end
  end
end
