require 'rails_helper'

RSpec.describe Idv::AbTestAnalyticsConcern do
  let(:user) { create(:user) }
  let(:idv_session) do
    Idv::Session.new(user_session: subject.user_session, current_user: user, service_provider: nil)
  end

  describe '#ab_test_analytics_buckets' do
    controller(ApplicationController) do
      include Idv::AbTestAnalyticsConcern

      def document_capture_session_uuid
        SecureRandom.uuid
      end
    end

    let(:acuant_sdk_args) { { as_bucket: :as_value } }

    before do
      allow(subject).to receive(:current_user).and_return(user)
    end

    context 'idv_session is available' do
      before do
        sign_in(user)
        allow(subject).to receive(:idv_session).and_return(idv_session)
      end

      it 'includes skip_hybrid_handoff' do
        idv_session.skip_hybrid_handoff = :shh_value
        expect(controller.ab_test_analytics_buckets).to include({ skip_hybrid_handoff: :shh_value })
      end

      context 'opted_in_to_in_person_proofing value' do
        before do
          idv_session.opted_in_to_in_person_proofing = :opt_in_value
        end

        it 'includes opted_in_to_in_person_proofing when enabled' do
          allow(IdentityConfig.store).to receive(:in_person_proofing_opt_in_enabled)
            .and_return(true)
          expect(controller.ab_test_analytics_buckets)
            .to include({ opted_in_to_in_person_proofing: :opt_in_value })
        end

        it 'does not include opted_in_to_in_person_proofing when disabled' do
          expect(controller.ab_test_analytics_buckets)
            .not_to include({ opted_in_to_in_person_proofing: :opt_in_value })
        end
      end
    end
  end
end
