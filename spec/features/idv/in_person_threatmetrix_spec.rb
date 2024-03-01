require 'rails_helper'

RSpec.describe 'In Person Proofing Threatmetrix', js: true, allowed_extra_analytics: [:*] do
  include IdvStepHelper
  include SpAuthHelper
  include InPersonHelper

  let(:sp) { :oidc }

  before do
    allow(IdentityConfig.store).to receive(:in_person_proofing_enabled).and_return(true)
    allow(IdentityConfig.store).to receive(:in_person_proofing_enforce_tmx).and_return(true)
    ServiceProvider.find_by(issuer: service_provider_issuer(sp)).
        update(in_person_proofing_enabled: true)
    
    let(:user) { user_with_2fa }
  end

  before(:each) do
    sign_in_and_2fa_user
    begin_in_person_proofing
    complete_all_in_person_proofing_steps(user, tmx_status)
    complete_phone_step(user)
    complete_enter_password_step(user)
    acknowledge_and_confirm_personal_key
  end

  context 'ThreatMetrix determination of Review' do
    let(:tmx_status) { 'Review' }

    context 'User passes IPP and TMX Review' do
        it 'initially shows the user the barcode page' do
        end

        it 'shows the user the Please Call screen after passing IPP' do
        end

        it 'sends the Please Call email after passing IPP' do
        end

        it 'does not allow the user to restart the IPP flow' do
        end

        it 'notifies the user after passing TMX review' do
        end

        it 'allows shows the user the successful verification screen after passing TMX review' do
        end
    end

    context 'User fails IPP and passes TMX review' do

    end

    context 'User fails IPP and fails TMX review' do

    end
  end

  context 'ThreatMetrix determination of Reject' do
    let(:tmx_status) { 'Reject' }

    context 'User passes IPP and fails TMX review' do

    end
  end
end