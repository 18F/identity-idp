require 'rails_helper'

describe 'OpenID Connect' do
  include IdvFromSpHelper
  include OidcAuthHelper
  include DocAuthHelper

  let(:email) { 'test@test.com' }
  let(:password) { RequestHelper::VALID_PASSWORD }
  let(:today) { Time.zone.today }
  let(:client_id_1) { 'urn:gov:gsa:openidconnect:sp:server' }
  let(:client_id_2) { 'urn:gov:gsa:openidconnect:sp:server_two' }
  let(:issuer_1) { 'https://rp1.serviceprovider.com/auth/saml/metadata' }
  let(:issuer_2) { 'https://rp3.serviceprovider.com/auth/saml/metadata' }

  context 'an IAL1 user with an active session' do
    before do
      create_ial1_user_from_sp(email)
      user = User.find_with_email(email)
    end

    context 'using oidc' do
      it 'does not count second IAL1 auth at same sp' do
        visit_idp_from_ial1_oidc_sp(client_id: client_id_1)
        click_continue
        expect_ial1_count_only(client_id_1)

        visit_idp_from_ial1_oidc_sp(client_id: client_id_1)
        click_continue
        expect_ial1_count_only(client_id_1)
      end

      it 'counts step up from IAL1 to IAL2 after proofing' do
        visit_idp_from_ial1_oidc_sp(client_id: client_id_1)
        click_continue
        expect_ial1_count_only(client_id_1)

        visit_idp_from_ial2_oidc_sp(client_id: client_id_1)
        complete_proofing_steps
        expect_ial1_and_ial2_count(client_id_1)
      end
    end

    context 'using saml' do
      it 'does not count second IAL1 auth at same sp' do
        visit_idp_from_ial1_saml_sp(issuer: issuer_1)
        click_agree_and_continue
        expect_ial1_count_only(issuer_1)

        visit_idp_from_ial1_saml_sp(issuer: issuer_1)
        click_continue
        expect_ial1_count_only(issuer_1)
      end

      it 'counts step up from IAL1 to IAL2 after proofing' do
        visit_idp_from_ial1_saml_sp(issuer: issuer_1)
        click_agree_and_continue
        expect_ial1_count_only(issuer_1)

        visit_idp_from_ial2_saml_sp(issuer: issuer_1)
        complete_proofing_steps
        expect_ial1_and_ial2_count(issuer_1)
      end
    end
  end


  context 'an IAL2 user with an active session' do
    before do
      create_ial2_user_from_sp(email)
      user = User.find_with_email(email)
    end

    context 'using oidc' do

      it 'counts IAL1 auth at same sp' do
        visit_idp_from_ial2_oidc_sp(client_id: client_id_1)
        click_continue
        expect_ial2_count_only(client_id_1)

        visit_idp_from_ial1_oidc_sp(client_id: client_id_1)
        click_continue
        expect_ial1_and_ial2_count(client_id_1)
      end

      it 'does not count second IAL2 auth at same sp' do
        visit_idp_from_ial2_oidc_sp(client_id: client_id_1)
        click_continue
        expect_ial2_count_only(client_id_1)

        visit_idp_from_ial2_oidc_sp(client_id: client_id_1)
        click_continue
        expect_ial2_count_only(client_id_1)
      end

      it 'counts step up from IAL1 to IAL2 at another sp' do
        visit_idp_from_ial1_oidc_sp(client_id: client_id_2)
        click_agree_and_continue
        expect_ial1_count_only(client_id_2)

        visit_idp_from_ial2_oidc_sp(client_id: client_id_2)
        click_agree_and_continue
        expect_ial1_and_ial2_count(client_id_2)
      end

      it 'counts IAL2 auth at another sp' do
        visit_idp_from_ial2_oidc_sp(client_id: client_id_1)
        click_continue
        expect_ial2_count_only(client_id_1)

        visit_idp_from_ial2_oidc_sp(client_id: client_id_2)
        click_agree_and_continue
        expect_ial2_count_only(client_id_2)
      end

      it 'counts IAL1 auth at another sp' do
        visit_idp_from_ial1_oidc_sp(client_id: client_id_1)
        click_continue
        expect_ial1_and_ial2_count(client_id_1)

        visit_idp_from_ial1_oidc_sp(client_id: client_id_2)
        click_agree_and_continue
        expect_ial1_count_only(client_id_2)
      end
    end

    context 'using saml' do

      it 'counts IAL1 auth at same sp' do
        visit_idp_from_ial2_saml_sp(issuer: issuer_1)
        click_agree_and_continue
        expect_ial2_count_only(issuer_1)

        visit_idp_from_ial1_saml_sp(issuer: issuer_1)
        click_agree_and_continue
        expect_ial1_and_ial2_count(issuer_1)
      end

      it 'does not count second IAL2 auth at same sp' do
        visit_idp_from_ial2_saml_sp(issuer: issuer_1)
        click_agree_and_continue
        expect_ial2_count_only(issuer_1)

        visit_idp_from_ial2_saml_sp(issuer: issuer_1)
        click_continue
        expect_ial2_count_only(issuer_1)
      end

      it 'counts step up from IAL1 to IAL2 at same sp' do
        visit_idp_from_ial1_saml_sp(issuer: issuer_1)
        click_agree_and_continue
        expect_ial1_count_only(issuer_1)

        visit_idp_from_ial2_saml_sp(issuer: issuer_1)
        click_agree_and_continue
        expect_ial1_and_ial2_count(issuer_1)
      end

      it 'counts IAL1 auth at another sp' do
        visit_idp_from_ial1_saml_sp(issuer: issuer_1)
        click_agree_and_continue
        expect_ial1_count_only(issuer_1)

        visit_idp_from_ial1_saml_sp(issuer: issuer_2)
        click_agree_and_continue
        expect_ial1_count_only(issuer_2)
      end

      it 'counts IAL2 auth at another sp' do
        visit_idp_from_ial2_saml_sp(issuer: issuer_1)
        click_agree_and_continue
        expect_ial2_count_only(issuer_1)

        visit_idp_from_ial2_saml_sp(issuer: issuer_2)
        click_agree_and_continue
        expect_ial2_count_only(issuer_2)
      end
    end


  end

  # today = Time.zone.today
  # Db::MonthlySpAuthCount::SpMonthTotalAuthCounts.call(today, client_id, 1)
  # Time.zone.today

  # sign_in_user(user)
  # sign_in_and_2fa_user(user)
  # visit destroy_user_session_path

  def expect_ial1_count_only(issuer)
    expect(ial1_monthly_auth_count(issuer)).to eq(1)
    expect(ial2_monthly_auth_count(issuer)).to eq(0)
  end

  def expect_ial2_count_only(issuer)
    expect(ial1_monthly_auth_count(issuer)).to eq(0)
    expect(ial2_monthly_auth_count(issuer)).to eq(1)
  end

  def expect_ial1_and_ial2_count(issuer)
    expect(ial1_monthly_auth_count(issuer)).to eq(1)
    expect(ial2_monthly_auth_count(issuer)).to eq(1)
  end

  def ial2_monthly_auth_count(client_id)
    Db::MonthlySpAuthCount::SpMonthTotalAuthCounts.call(today, client_id, 2)
  end

  def ial1_monthly_auth_count(client_id)
    Db::MonthlySpAuthCount::SpMonthTotalAuthCounts.call(today, client_id, 1)
  end
end
