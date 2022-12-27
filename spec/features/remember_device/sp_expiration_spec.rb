require 'rails_helper'

shared_examples 'expiring remember device for an sp config' do |expiration_time, protocol|
  before do
    user # Go through the signup flow and remember user before visiting SP
  end

  context "#{protocol}: signing in" do
    it "does not require MFA before #{expiration_time.inspect}" do
      travel_to(expiration_time.from_now - 1.day) do
        visit_idp_from_sp_with_ial1(protocol)
        sign_in_user(user)
        click_submit_default if protocol == :saml
        expect(page).to have_current_path(sign_up_completed_path)
      end
    end

    it "does require MFA after #{expiration_time.inspect}" do
      travel_to(expiration_time.from_now + 1.day) do
        visit_idp_from_sp_with_ial1(protocol)
        sign_in_user(user)

        expect(page).to have_content(t('two_factor_authentication.header_text'))
        expect(current_path).to eq(login_two_factor_path(otp_delivery_preference: :sms))

        fill_in_code_with_last_phone_otp
        protocol == :saml ? click_submit_default_twice : click_submit_default

        expect(page).to have_current_path(sign_up_completed_path)
      end
    end

    it 'requires MFA when AAL2 request is sent after 12 hours' do
      travel_to(12.hours.from_now + 1.day) do
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

  context "#{protocol}: visiting while already signed in" do
    it "does not require MFA before #{expiration_time.inspect}" do
      travel_to(expiration_time.from_now - 1.day) do
        sign_in_user(user)
        visit_idp_from_sp_with_ial1(protocol)

        expect(page).to have_current_path(sign_up_completed_path)
      end
    end

    it "does require MFA after #{expiration_time.inspect}" do
      travel_to(expiration_time.from_now + 1.day) do
        if expiration_time == 30.days
          sign_in_live_with_2fa(user)
          visit_idp_from_sp_with_ial1(protocol)
        else
          sign_in_user(user)
          visit_idp_from_sp_with_ial1(protocol)

          expect(page).to have_content(t('two_factor_authentication.header_text'))
          expect(current_path).to eq(login_two_factor_path(otp_delivery_preference: :sms))

          fill_in_code_with_last_phone_otp
          protocol == :saml ? click_submit_default_twice : click_submit_default
        end

        expect(page).to have_current_path(sign_up_completed_path)
      end
    end

    it 'does require MFA when AAL2 request is sent after 12 hours' do
      travel_to(12.hours.from_now + 1.day) do
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

feature 'remember device sp expiration' do
  include SamlAuthHelper

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

    first(:link, t('links.sign_out')).click
    user_record
  end

  before do
    allow(IdentityConfig.store).to receive(:otp_delivery_blocklist_maxretry).and_return(1000)

    ServiceProvider.find_by(issuer: 'urn:gov:gsa:openidconnect:sp:server').update!(
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

      it_behaves_like 'expiring remember device for an sp config', 12.hours, :oidc
      it_behaves_like 'expiring remember device for an sp config', 12.hours, :saml
    end

    context 'with an IAL2 SP' do
      let(:aal) { 1 }
      let(:ial) { 2 }

      it_behaves_like 'expiring remember device for an sp config', 12.hours, :oidc
      it_behaves_like 'expiring remember device for an sp config', 12.hours, :saml
    end

    context 'with an AAL2 and IAL2 SP' do
      let(:aal) { 2 }
      let(:ial) { 2 }

      it_behaves_like 'expiring remember device for an sp config', 12.hours, :oidc
      it_behaves_like 'expiring remember device for an sp config', 12.hours, :saml
    end

    context 'with an AAL1 and IAL1 SP' do
      let(:aal) { 1 }
      let(:ial) { 1 }

      it_behaves_like 'expiring remember device for an sp config', 30.days, :oidc
      it_behaves_like 'expiring remember device for an sp config', 30.days, :saml
    end
  end
end
