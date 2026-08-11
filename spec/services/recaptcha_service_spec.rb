require 'rails_helper'

RSpec.describe RecaptchaService do
  let(:analytics) { FakeAnalytics.new }

  describe '#create_assessment' do
    let(:recaptcha_token) { 'TOKEN' }
    let(:recaptcha_action) { 'ACTION' }
    let(:user_agent) { 'Example/1.0' }
    let(:user_ip_address) { '127.0.0.1' }
    subject(:create_assessment) do
      RecaptchaService.new.create_assessment(
        recaptcha_token:,
        recaptcha_action:,
        user_agent:,
        user_ip_address:,
      )
    end
    let(:recaptcha_client) { instance_double('Google::Cloud::RecaptchaEnterprise::RecaptchaEnterpriseService::Client') }
    let(:recaptcha_assessment) { instance_double('Google::Cloud::RecaptchaEnterprise::Assessment') }

    before(:example) do
      allow(Google::Auth::APIKeyCredentials).to receive(:make_creds)
      allow(Google::Cloud::RecaptchaEnterprise).to receive(:recaptcha_enterprise_service)
        .and_return(recaptcha_client)
      allow(recaptcha_client).to receive(:create_assessment).with(anything)
        .and_return(recaptcha_assessment)
    end

    context 'when the token is invalid' do
      let(:invalid_reason) { 'MALFORMED' }

      before do
        allow(recaptcha_assessment).to receive_message_chain('token_properties.valid')
          .and_return(false)
        allow(recaptcha_assessment).to receive_message_chain('token_properties.invalid_reason')
          .and_return(invalid_reason)
      end

      it 'fails with the correct error' do
        result = create_assessment
        expect(result.success).to be(false)
        expect(result.errors).to eq([invalid_reason])
      end
    end

    context 'when the token is valid' do
      context 'when the action is different from the expected action' do
        let(:different_action) { 'DIFFERENT ACTION' }

        before do
          allow(recaptcha_assessment).to receive_message_chain('token_properties.valid')
            .and_return(true)
          allow(recaptcha_assessment).to receive_message_chain('token_properties.action')
            .and_return(different_action)
        end

        it 'fails with the correct error' do
          result = create_assessment
          expect(result.success).to be(false)
          expect(result.errors).to eq(
            ["Unexpected action #{different_action}, expected #{recaptcha_action}"],
          )
        end
      end

      context 'when the action is the same as the expected action' do
        before do
          allow(recaptcha_assessment).to receive_message_chain('token_properties.valid')
            .and_return(true)
          allow(recaptcha_assessment).to receive_message_chain('token_properties.action')
            .and_return(recaptcha_action)
          allow(recaptcha_assessment).to receive('name')
            .and_return('ASSESSMENT_ID')
          allow(recaptcha_assessment).to receive_message_chain('risk_analysis.score')
            .and_return(0.1)
          allow(recaptcha_assessment).to receive_message_chain('risk_analysis.reasons')
            .and_return('AUTOMATION')
        end

        it 'succeeds with the assessment_id, score, and reasons' do
          result = create_assessment
          expect(result.success).to be(true)
          expect(result.errors).to be_empty
          expect(result.assessment_id).to eq('ASSESSMENT_ID')
          expect(result.score).to eq(0.1)
          expect(result.reasons).to eq('AUTOMATION')
        end

        it 'includes the user agent and user ip address in the assessment event' do
          allow(FeatureManagement).to receive(:recaptcha_enterprise_additional_context_enabled?)
            .and_return(true)

          expect(recaptcha_client).to receive(:create_assessment) do |request|
            event = request[:assessment][:event]
            expect(event[:user_agent]).to eq(user_agent)
            expect(event[:user_ip_address]).to eq(user_ip_address)
            recaptcha_assessment
          end

          create_assessment
        end

        context 'when additional context is enabled' do
          before do
            allow(FeatureManagement).to receive(:recaptcha_enterprise_additional_context_enabled?)
              .and_return(true)
          end

          context 'when the user agent and user ip address are not provided' do
            subject(:create_assessment) do
              RecaptchaService.new.create_assessment(recaptcha_token:, recaptcha_action:)
            end

            it 'omits them from the assessment event' do
              expect(recaptcha_client).to receive(:create_assessment) do |request|
                event = request[:assessment][:event]
                expect(event).not_to have_key(:user_agent)
                expect(event).not_to have_key(:user_ip_address)
                recaptcha_assessment
              end

              create_assessment
            end
          end

          context 'when the user agent and user ip address are blank' do
            let(:user_agent) { '' }
            let(:user_ip_address) { '' }

            it 'omits them from the assessment event' do
              expect(recaptcha_client).to receive(:create_assessment) do |request|
                event = request[:assessment][:event]
                expect(event).not_to have_key(:user_agent)
                expect(event).not_to have_key(:user_ip_address)
                recaptcha_assessment
              end

              create_assessment
            end
          end
        end

        context 'when additional context is disabled' do
          before do
            allow(FeatureManagement).to receive(:recaptcha_enterprise_additional_context_enabled?)
              .and_return(false)
          end

          it 'omits the user agent and user ip address from the assessment event' do
            expect(recaptcha_client).to receive(:create_assessment) do |request|
              event = request[:assessment][:event]
              expect(event.keys).to contain_exactly(:site_key, :token)
              recaptcha_assessment
            end

            create_assessment
          end
        end
      end
    end
  end
end
