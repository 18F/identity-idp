require 'rails_helper'

RSpec.describe TwoFactorAuthenticatableMethods, type: :controller do
  controller ApplicationController do
    include TwoFactorAuthenticatableMethods
  end

  describe '#handle_valid_verification_for_authentication_context' do
    let(:user) { create(:user) }
    let(:auth_method) { TwoFactorAuthenticatable::AuthMethod::REMEMBER_DEVICE }

    subject(:result) do
      controller.handle_valid_verification_for_authentication_context(auth_method:)
    end

    before do
      stub_sign_in_before_2fa(user)
    end

    it 'tracks authentication event' do
      stub_analytics

      result

      expect(@analytics).to have_logged_event(
        'User marked authenticated',
        authentication_type: :valid_2fa,
      )
    end

    it 'authenticates user session auth methods' do
      expect(controller.auth_methods_session).to receive(:authenticate!).with(auth_method)

      result
    end

    it 'creates a new user event with disavowal' do
      expect { result }.to change { user.reload.events.count }.from(0).to(1)
      expect(user.events.last.event_type).to eq('sign_in_after_2fa')
      expect(user.events.last.disavowal_token_fingerprint).to be_present
    end

    context 'when authenticating without new device sign in' do
      let(:user) { create(:user) }

      context 'when alert aggregation feature is disabled' do
        before do
          allow(IdentityConfig.store).to receive(:feature_new_device_alert_aggregation_enabled).
            and_return(false)
        end

        it 'does not send an alert' do
          expect(UserAlerts::AlertUserAboutNewDevice).to_not receive(:send_alert)

          result
        end
      end

      context 'when alert aggregation feature is enabled' do
        before do
          allow(IdentityConfig.store).to receive(:feature_new_device_alert_aggregation_enabled).
            and_return(true)
        end

        context 'with an existing device' do
          before do
            allow(controller).to receive(:new_device?).and_return(false)
          end

          it 'does not send an alert' do
            expect(UserAlerts::AlertUserAboutNewDevice).to_not receive(:send_alert)

            result
          end
        end

        context 'with a new device' do
          before do
            allow(controller).to receive(:new_device?).and_return(true)
          end

          it 'sends the new device alert using 2fa event date' do
            expect(UserAlerts::AlertUserAboutNewDevice).to receive(:send_alert) do |**args|
              expect(user.reload.sign_in_new_device_at.change(usec: 0)).to eq(
                args[:disavowal_event].created_at.change(usec: 0),
              )
              expect(args[:user]).to eq(user)
              expect(args[:disavowal_event]).to be_kind_of(Event)
              expect(args[:disavowal_token]).to be_kind_of(String)
            end
            result
          end

          context 'sign_in_notification_timeframe_expired missing' do
            it 'tracks analytics event for missing timeframe_expired' do
              stub_analytics
              result

              expect(@analytics).to have_logged_event(
                :sign_in_notification_timeframe_expired_absent,
              )
            end
          end

          context 'sign_in_notification_timeframe_expired present' do
            before do
              create(
                :event,
                user:,
                event_type: :sign_in_notification_timeframe_expired,
                created_at: 10.minutes.ago,
              )
            end

            around do |ex|
              freeze_time { ex.run }
            end

            it 'creates a new user event with disavowal' do
              expect(UserAlerts::AlertUserAboutNewDevice).to receive(:send_alert) do
                expect(user.reload.sign_in_new_device_at.change(usec: 0)).to eq(
                  10.minutes.ago,
                )
              end
              stub_analytics
              result

              expect(@analytics).to_not have_logged_event(
                :sign_in_notification_timeframe_expired_absent,
              )
            end
          end
        end
      end
    end

    context 'when authenticating with new device sign in' do
      let(:user) { create(:user, sign_in_new_device_at: Time.zone.now) }

      context 'when alert aggregation feature is disabled' do
        before do
          allow(IdentityConfig.store).to receive(:feature_new_device_alert_aggregation_enabled).
            and_return(false)
        end

        it 'does not send an alert' do
          expect(UserAlerts::AlertUserAboutNewDevice).to_not receive(:send_alert)

          result
        end
      end

      context 'when alert aggregation feature is enabled' do
        before do
          allow(IdentityConfig.store).to receive(:feature_new_device_alert_aggregation_enabled).
            and_return(true)
        end

        context 'with an existing device' do
          before do
            allow(controller).to receive(:new_device?).and_return(false)
          end

          it 'does not send an alert' do
            expect(UserAlerts::AlertUserAboutNewDevice).to_not receive(:send_alert)

            result
          end
        end

        context 'with a new device' do
          before do
            allow(controller).to receive(:new_device?).and_return(true)
          end

          it 'sends the new device alert' do
            expect(UserAlerts::AlertUserAboutNewDevice).to receive(:send_alert).
              with(user:, disavowal_event: kind_of(Event), disavowal_token: kind_of(String))

            result
          end
        end
      end
    end
  end
end
