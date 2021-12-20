require 'rails_helper'

describe SignUpCompletionsShow do
  before do
    @user = create(:user)
  end

  let(:handoff) { false }
  let(:consent_has_expired?) { false }
  let(:sp_session) {}

  subject(:view_model) do
    SignUpCompletionsShow.new(
      current_user: @user,
      ial2_requested: false,
      decorated_session: decorated_session,
      handoff: handoff,
      consent_has_expired: consent_has_expired?,
    )
  end

  context 'with an sp session' do
    let(:decorated_session) do
      ServiceProviderSessionDecorator.new(
        sp: build_stubbed(:service_provider),
        view_context: ActionController::Base.new.view_context,
        sp_session: sp_session,
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

    describe '#requested_attributes_sorted' do
      context 'the requested attributes include email' do
        let(:sp_session) { { requested_attributes: [:email] } }

        it 'includes the sign in email address' do
          expect(view_model.requested_attributes_sorted).to include(:email)
        end
      end

      context 'the requrested attributes include all_emails' do
        let(:sp_session) { { requested_attributes: [:email, :all_emails] } }

        it 'includes all email addresses and not the individual email address' do
          expect(view_model.requested_attributes_sorted).to include(:all_emails)
          expect(view_model.requested_attributes_sorted).to_not include(:email)
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
  end
end
