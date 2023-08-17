require 'rails_helper'

# rubocop:disable Layout/LineLength
RSpec.shared_examples 'expiring remember device for an sp config' do |expiration_time, protocol, aal|
  # rubocop:enable Layout/LineLength
  before do
    user # Go through the signup flow and remember user before visiting SP
  end

  def visit_sp(protocol, aal)
    if aal == 2
      visit_idp_from_sp_with_ial1_aal2(protocol)
    else
      visit_idp_from_sp_with_ial1(protocol)
    end
  end

  context "#{protocol}: signing in" do
    it "does not require MFA before #{expiration_time.inspect}" do
      travel_to(expiration_time.from_now - 1.day) do
        visit_sp(protocol, aal)
        sign_in_user(user)
        click_submit_default if protocol == :saml
        expect(page).to have_current_path(sign_up_completed_path)
      end
    end

    it "does require MFA after #{expiration_time.inspect}" do
      travel_to(expiration_time.from_now + 1.day) do
        visit_sp(protocol, aal)
        sign_in_user(user)

        expect(page).to have_content(t('two_factor_authentication.header_text'))
        expect(current_path).to eq(login_two_factor_path(otp_delivery_preference: :sms))

        fill_in_code_with_last_phone_otp
        protocol == :saml ? click_submit_default_twice : click_submit_default

        expect(page).to have_current_path(sign_up_completed_path)
      end
    end

    context "#{protocol}: visiting while already signed in" do
      it "does not require MFA before #{expiration_time.inspect}" do
        travel_to(expiration_time.from_now - 1.day) do
          sign_in_user(user)
          visit_sp(protocol, aal)

          expect(page).to have_current_path(sign_up_completed_path)
        end
      end

      it "does require MFA after #{expiration_time.inspect}" do
        travel_to(expiration_time.from_now + 1.day) do
          sign_in_user(user)
          visit_sp(protocol, aal)

          expect(current_path).to eq(login_two_factor_path(otp_delivery_preference: :sms))
          expect(page).to have_content(t('two_factor_authentication.header_text'))

          fill_in_code_with_last_phone_otp
          protocol == :saml ? click_submit_default_twice : click_submit_default

          expect(page).to have_current_path(sign_up_completed_path)
        end
      end

      it 'does require MFA when AAL2 request is sent after configured AAL2 timeframe' do
        travel_to(AAL2_REMEMBER_DEVICE_EXPIRATION.from_now + 1.day) do
          visit_idp_from_sp_with_ial1_aal2(protocol)
          sign_in_user(user)

          expect(page).to have_content(t('two_factor_authentication.header_text'))
          expect(current_path).to eq(login_two_factor_path(otp_delivery_preference: :sms))

          fill_in_code_with_last_phone_otp
          protocol == :saml ? click_submit_default_twice : click_submit_default

          expect(page).to have_current_path(sign_up_completed_path)
        end
      end
    end
  end
end

RSpec.feature 'remember device sp expiration' do
  include SamlAuthHelper
  AAL1_REMEMBER_DEVICE_EXPIRATION =
    IdentityConfig.store.remember_device_expiration_hours_aal_1.hours
  AAL2_REMEMBER_DEVICE_EXPIRATION =
    IdentityConfig.store.remember_device_expiration_minutes_aal_2.minutes

  let(:user) do
    user_record = sign_up_and_set_password
    user_record.password = Features::SessionHelper::VALID_PASSWORD

    select_2fa_option('phone')
    fill_in :new_phone_form_phone, with: '2025551212'
    click_send_one_time_code
    check t('forms.messages.remember_device')
    fill_in_code_with_last_phone_otp
    click_submit_default
    skip_second_mfa_prompt

    first(:button, t('links.sign_out')).click
    user_record
  end

  before do
    allow(IdentityConfig.store).to receive(:otp_delivery_blocklist_maxretry).and_return(1000)

    ServiceProvider.find_by(issuer: OidcAuthHelper::OIDC_IAL1_ISSUER).update!(
      default_aal: aal,
      ial: ial,
    )
    ServiceProvider.find_by(issuer: 'http://localhost:3000').update!(
      default_aal: aal,
      ial: ial,
    )
  end

  context 'signing into an SP' do
    context 'with an AAL2 SP' do
      let(:aal) { 2 }
      let(:ial) { 1 }

      it_behaves_like 'expiring remember device for an sp config', AAL2_REMEMBER_DEVICE_EXPIRATION,
                      :oidc
      it_behaves_like 'expiring remember device for an sp config', AAL2_REMEMBER_DEVICE_EXPIRATION,
                      :saml
    end

    context 'with an IAL2 SP' do
      let(:aal) { 1 }
      let(:ial) { 2 }

      it_behaves_like 'expiring remember device for an sp config', AAL2_REMEMBER_DEVICE_EXPIRATION,
                      :oidc
      it_behaves_like 'expiring remember device for an sp config', AAL2_REMEMBER_DEVICE_EXPIRATION,
                      :saml
    end

    context 'with an AAL2 and IAL2 SP' do
      let(:aal) { 2 }
      let(:ial) { 2 }

      it_behaves_like 'expiring remember device for an sp config', AAL2_REMEMBER_DEVICE_EXPIRATION,
                      :oidc
      it_behaves_like 'expiring remember device for an sp config', AAL2_REMEMBER_DEVICE_EXPIRATION,
                      :saml
    end

    context 'with an AAL1 and IAL1 SP' do
      let(:aal) { 1 }
      let(:ial) { 1 }

      it_behaves_like 'expiring remember device for an sp config', AAL1_REMEMBER_DEVICE_EXPIRATION,
                      :oidc
      it_behaves_like 'expiring remember device for an sp config', AAL1_REMEMBER_DEVICE_EXPIRATION,
                      :saml
    end

    context 'with an AAL1 and IAL1 SP requesting AAL2' do
      let(:aal) { 1 }
      let(:ial) { 1 }

      it_behaves_like 'expiring remember device for an sp config', AAL2_REMEMBER_DEVICE_EXPIRATION,
                      :oidc, 2
      it_behaves_like 'expiring remember device for an sp config', AAL2_REMEMBER_DEVICE_EXPIRATION,
                      :saml, 2
    end
  end
end
