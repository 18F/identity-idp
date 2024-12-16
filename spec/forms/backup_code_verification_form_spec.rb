require 'rails_helper'

RSpec.describe BackupCodeVerificationForm do
  include DOTIW::Methods

  subject(:result) { form.submit(params) }

  let(:form) { described_class.new(user:, request:) }
  let(:user) { create(:user) }
  let(:request) { FakeRequest.new }
  let(:backup_codes) { BackupCodeGenerator.new(user).delete_and_regenerate }
  let(:backup_code_config) do
    BackupCodeConfiguration.find_with_code(code: code, user_id: user.id)
  end

  describe '#submit' do
    let(:params) { { backup_code: code } }

    context 'with a valid backup code' do
      let(:code) { backup_codes.first }

      it 'returns success' do
        expect(result.to_h).to eq(
          success: true,
          multi_factor_auth_method_created_at: backup_code_config.created_at.strftime('%s%L'),
        )
      end

      it 'marks code as used' do
        expect { subject }
          .to change { backup_code_config.reload.used_at }
          .from(nil)
          .to kind_of(Time)
      end
    end

    context 'with an invalid backup code' do
      let(:code) { 'invalid' }

      it 'returns failure' do
        expect(result.first_error_message).to eq(t('two_factor_authentication.invalid_backup_code'))
        expect(result.to_h).to eq(
          success: false,
          error_details: { backup_code: { invalid: true } },
          multi_factor_auth_method_created_at: nil,
        )
      end
    end

    describe 'rate limiting', :freeze_time do
      before do
        allow(RateLimiter).to receive(:rate_limit_config).and_return(
          backup_code_user_id_per_ip: {
            max_attempts: 2,
            attempt_window: 60,
            attempt_window_exponential_factor: 3,
            attempt_window_max: 12.hours.in_minutes,
          },
        )
      end

      context 'before hitting rate limit' do
        context 'with an invalid code' do
          let(:code) { 'invalid' }

          it 'returns failure due to invalid code' do
            expect(result.first_error_message).to eq(
              t('two_factor_authentication.invalid_backup_code'),
            )
            expect(result.to_h).to eq(
              success: false,
              error_details: { backup_code: { invalid: true } },
              multi_factor_auth_method_created_at: nil,
            )
          end
        end
      end

      context 'after hitting rate limit' do
        before do
          form.submit(params.merge(backup_code: 'invalid'))
        end

        context 'with an invalid code' do
          let(:code) { 'invalid' }

          it 'returns failure due to rate limiting' do
            expect(result.first_error_message).to eq(
              t(
                'errors.messages.phone_confirmation_limited',
                timeout: distance_of_time_in_words(3.hours),
              ),
            )
            expect(result.to_h).to eq(
              success: false,
              error_details: { backup_code: { rate_limited: true } },
              multi_factor_auth_method_created_at: nil,
            )
          end
        end

        context 'with a valid code' do
          let(:code) { backup_codes.first }

          it 'returns failure due to rate limiting' do
            expect(result.first_error_message).to eq(
              t(
                'errors.messages.phone_confirmation_limited',
                timeout: distance_of_time_in_words(3.hours),
              ),
            )
            expect(result.to_h).to eq(
              success: false,
              error_details: { backup_code: { rate_limited: true } },
              multi_factor_auth_method_created_at: nil,
            )
          end

          it 'does not consume code' do
            result

            configuration = BackupCodeConfiguration.find_with_code(code:, user_id: user.id)
            expect(configuration.used_at).to be_blank
          end
        end
      end
    end
  end
end
