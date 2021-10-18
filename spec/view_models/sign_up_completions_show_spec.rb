require 'rails_helper'

describe SignUpCompletionsShow do
  before do
    @user = create(:user)
  end

  let(:handoff) { false }
  let(:consent_has_expired?) { false }

  subject(:view_model) do
    SignUpCompletionsShow.new(
      current_user: @user,
      ial2_requested: false,
      decorated_session: decorated_session,
      handoff: handoff,
      ialmax_requested: false,
      consent_has_expired: consent_has_expired?,
    )
  end

  context 'with an sp session' do
    let(:decorated_session) do
      ServiceProviderSessionDecorator.new(
        sp: build_stubbed(:service_provider),
        view_context: ActionController::Base.new.view_context,
        sp_session: {},
        service_provider_request: ServiceProviderRequestProxy.new,
      )
    end

    describe '#heading' do
      subject(:heading) { view_model.heading }

      context 'for a handoff page' do
        let(:handoff) { true }

        it 'defaults to first time copy' do
          expect(heading).to include(I18n.t('titles.sign_up.new_sp'))
        end

        context 'when SP consent has expired' do
          let(:consent_has_expired?) { true }

          it 'uses refresh copy' do
            expect(heading).
              to include(view_model.content_tag(:strong, I18n.t('titles.sign_up.refresh_consent')))
          end
        end
      end
    end

    describe '#title' do
      subject(:title) { view_model.title }

      context 'for ial2 flow' do
        before do
          allow(@user).to receive(:active_profile).and_return(Profile.new)
        end

        it 'returns proper title name' do
          expect(title).
            to include(I18n.t('titles.sign_up.verified', app_name: APP_NAME))
        end
      end

      context 'for ial1 flow' do
        before do
          allow(@user).to receive(:active_profile).and_return(nil)
        end

        it 'returns proper title name' do
          expect(title).
            to include(
              I18n.t(
                'titles.sign_up.completion_html',
                accent: I18n.t('titles.sign_up.loa1'),
                app_name: APP_NAME,
              ),
            )
        end
      end
    end
  end

  context 'with no sp session' do
    let(:decorated_session) do
      SessionDecorator.new
    end

    let(:create_identity) do
      create(:service_provider_identity, user_id: @user.id)
    end

    describe '#identities' do
      it 'returns a users identities' do
        identity = create_identity
        expect(view_model.identities).to eq([identity])
      end
    end

    describe '#user_has_identities?' do
      it 'returns true if user has identities' do
        create_identity
        expect(view_model.user_has_identities?).to eq(true)
      end

      it 'returns false if user has no identities' do
        expect(view_model.user_has_identities?).to eq(false)
      end
    end
  end
end
