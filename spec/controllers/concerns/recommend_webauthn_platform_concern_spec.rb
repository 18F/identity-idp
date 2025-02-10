require 'rails_helper'

RSpec.describe RecommendWebauthnPlatformConcern do
  controller ApplicationController do
    include RecommendWebauthnPlatformConcern
  end

  let(:user) { create(:user, :fully_registered) }
  let(:platform_authenticator_available) { false }
  let(:in_account_creation_flow) { false }

  before do
    stub_sign_in(user)
    controller.user_session[:platform_authenticator_available] = platform_authenticator_available
    controller.user_session[:in_account_creation_flow] = in_account_creation_flow
  end

  describe '#recommend_webauthn_platform_for_sms_user?' do
    let(:bucket) { :recommend_for_account_creation }

    subject(:recommend_webauthn_platform_for_sms_user?) do
      controller.recommend_webauthn_platform_for_sms_user?(bucket)
    end

    context 'device is not supported for platform authenticator setup' do
      let(:platform_authenticator_available) { false }

      it { is_expected.to eq(false) }
    end

    context 'device is supported for platform authenticator setup' do
      let(:platform_authenticator_available) { true }

      context 'locale is anything other than english' do
        before do
          I18n.locale = (I18n.available_locales - [:en]).sample
        end

        it { is_expected.to eq(false) }
      end

      context 'locale is english' do
        before do
          I18n.locale = :en
        end

        context 'user was already recommended for setup' do
          let(:user) do
            create(
              :user,
              :fully_registered,
              webauthn_platform_recommended_dismissed_at: 2.minutes.ago,
            )
          end

          it { is_expected.to eq(false) }
        end

        context 'user has not yet been recommended for setup' do
          let(:user) { create(:user, :fully_registered) }

          context 'user is in authentication flow' do
            let(:in_account_creation_flow) { false }

            context 'user authenticated with an mfa method other than sms' do
              before do
                controller.auth_methods_session.auth_events.clear
                controller.auth_methods_session.authenticate!(
                  TwoFactorAuthenticatable::AuthMethod::VOICE,
                )
              end

              it { is_expected.to eq(false) }
            end

            context 'user authenticated with sms' do
              before do
                controller.auth_methods_session.auth_events.clear
                controller.auth_methods_session.authenticate!(
                  TwoFactorAuthenticatable::AuthMethod::SMS,
                )
              end

              context 'user has platform authenticator associated with their account' do
                let(:user) { create(:user, :fully_registered, :with_webauthn_platform) }

                it { is_expected.to eq(false) }
              end

              context 'user does not have platform authenticator associated with their account' do
                let(:user) { create(:user, :fully_registered) }

                context 'user not included in ab test' do
                  before do
                    expect(controller).to receive(:ab_test_bucket)
                      .with(:RECOMMEND_WEBAUTHN_PLATFORM_FOR_SMS_USER)
                      .and_return(nil)
                  end

                  it { is_expected.to eq(false) }
                end

                context 'user included in ab test' do
                  before do
                    expect(controller).to receive(:ab_test_bucket)
                      .with(:RECOMMEND_WEBAUTHN_PLATFORM_FOR_SMS_USER)
                      .and_return(bucket)
                  end

                  it { is_expected.to eq(true) }
                end
              end
            end
          end

          context 'user is in account creation flow' do
            let(:in_account_creation_flow) { true }

            context 'user set up methods not including phone' do
              let(:user) { create(:user, :fully_registered, :with_authentication_app) }

              before do
                user.phone_configurations.destroy_all
              end

              it { is_expected.to eq(false) }
            end

            context 'user set up phone as an mfa method' do
              let(:user) { create(:user, :fully_registered) }

              context 'user set up phone using voice delivery preference' do
                before do
                  user.phone_configurations.update_all(delivery_preference: :voice)
                end

                it { is_expected.to eq(false) }
              end

              context 'user set up phone using sms delivery preference' do
                before do
                  user.phone_configurations.update_all(delivery_preference: :sms)
                end

                context 'user also set up platform authenticator' do
                  let(:user) { create(:user, :fully_registered, :with_webauthn_platform) }

                  it { is_expected.to eq(false) }
                end

                context 'user did not set up platform authenticator' do
                  let(:user) { create(:user, :fully_registered) }

                  context 'user not included in ab test' do
                    before do
                      expect(controller).to receive(:ab_test_bucket)
                        .with(:RECOMMEND_WEBAUTHN_PLATFORM_FOR_SMS_USER)
                        .and_return(nil)
                    end

                    it { is_expected.to eq(false) }
                  end

                  context 'user included in ab test' do
                    before do
                      expect(controller).to receive(:ab_test_bucket)
                        .with(:RECOMMEND_WEBAUTHN_PLATFORM_FOR_SMS_USER)
                        .and_return(bucket)
                    end

                    it { is_expected.to eq(true) }
                  end
                end
              end
            end
          end
        end
      end
    end
  end
end
