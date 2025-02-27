# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Idv::IdTypePolicy do
  let(:vendor) { :lexis_nexis }
  let(:lexis_nexis_percent) { 0 }
  let(:socure_percent) { 0 }
  let(:passports_available) { true }
  let(:user) { create(:user) }
  let(:session) { {} }
  let(:user_session) { { idv: {} } }
  subject { described_class.new(user: user, session: session, user_session: user_session) }

  before do
    allow(IdentityConfig.store).to receive(:doc_auth_vendor).and_return(vendor)
    allow(IdentityConfig.store).to receive(:doc_auth_vendor_default).and_return(vendor)
    allow(IdentityConfig.store).to receive(:doc_auth_vendor_switching_enabled).and_return(true)
    allow(IdentityConfig.store).to receive(:doc_auth_vendor_socure_percent)
      .and_return(socure_percent)
    allow(IdentityConfig.store).to receive(:doc_auth_vendor_lexis_nexis_percent)
      .and_return(lexis_nexis_percent)
    allow(subject).to receive(:passport_option_available?).and_return(passports_available)

    dcs = DocumentCaptureSession.create(user_id: user.id, issuer: 'foo')
    session[:document_capture_session_uuid] = dcs.uuid

    reload_ab_tests
  end

  context 'when user is bucketed to lexis_nexis' do
    let(:lexis_nexis_percent) { 100 }

    context 'when passports are enabled' do
      it 'allows passports' do
        expect(subject.allow_passport?).to eq(true)
      end
    end

    context 'when passports are disabled' do
      let(:passports_available) { false }

      it 'does not allow passports' do
        expect(subject.allow_passport?).to eq(false)
      end
    end
  end

  context 'when user is bucketed to socure' do
    let(:vendor) { :socure }
    let(:socure_percent) { 100 }

    context 'when passports are enabled' do
      it 'does not allow passports' do
        expect(subject.allow_passport?).to eq(false)
      end
    end

    context 'when passports are disabled' do
      let(:passports_available) { false }

      it 'does not allow passports' do
        expect(subject.allow_passport?).to eq(false)
      end
    end
  end
end
