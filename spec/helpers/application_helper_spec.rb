require 'rails_helper'

describe ApplicationHelper do
  describe '#session_with_trust?' do
    context 'no user present' do
      before do
        allow(controller).to receive(:current_user).and_return(nil)
      end

      context 'current path is new session path' do
        it 'returns false' do
          allow(helper).to receive(:current_page?).with(
            controller: 'users/sessions', action: 'new',
          ).and_return(true)

          expect(helper.session_with_trust?).to eq false
        end
      end

      context 'current path is not new session path' do
        it 'returns true' do
          allow(helper).to receive(:current_page?).with(
            controller: 'users/sessions', action: 'new',
          ).and_return(false)

          expect(helper.session_with_trust?).to eq true
        end
      end
    end

    context 'curent user is present' do
      it 'returns true' do
        allow(controller).to receive(:current_user).and_return(true)

        expect(helper.session_with_trust?).to eq true
      end
    end
  end

  describe '#liveness_checking_enabled?' do
    let(:liveness_checking_enabled) { false }
    let(:sp_session) { {} }
    let(:current_user) { nil }
    before do
      allow(FeatureManagement).to receive(:liveness_checking_enabled?).
        and_return(liveness_checking_enabled)
      allow(helper).to receive(:sp_session).and_return(sp_session)
      allow(helper).to receive(:current_user).and_return(current_user)
    end

    context 'feature disabled' do
      it 'returns false' do
        expect(helper.liveness_checking_enabled?).to eq(false)
      end
    end

    context 'feature enabled' do
      let(:liveness_checking_enabled) { true }

      context 'sp requests no liveness' do
        let(:sp_session) { { ial2_strict: false } }

        it 'returns false' do
          expect(helper.liveness_checking_enabled?).to eq(false)
        end
      end

      context 'sp requests liveness' do
        let(:sp_session) { { ial2_strict: true } }

        it 'returns true' do
          expect(helper.liveness_checking_enabled?).to eq(true)
        end
      end

      context 'no current user' do
        it 'returns false' do
          expect(helper.liveness_checking_enabled?).to eq(false)
        end
      end

      context 'current user has no profiles' do
        let(:current_user) { create(:user) }

        it 'returns false' do
          expect(helper.liveness_checking_enabled?).to eq(false)
        end
      end

      context 'current user has no profiles with liveness' do
        let(:current_user) do
          create(
            :user,
            profiles: [
              create(
                :profile,
                :verified,
                :password_reset,
              ),
            ],
          )
        end

        it 'returns false' do
          expect(helper.liveness_checking_enabled?).to eq(false)
        end
      end

      context 'current user has profile with strict IAL2' do
        let(:current_user) do
          create(
            :user,
            profiles: [
              create(
                :profile,
                :active,
                :verified,
                :password_reset,
                proofing_components: {
                  liveness_check: DocAuthRouter.doc_auth_vendor,
                  address_check: :lexis_nexis_address,
                },
              ),
            ],
          )
        end

        it 'returns true' do
          expect(helper.liveness_checking_enabled?).to eq(true)
        end
      end
    end
  end
end
