# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Idv::DocPiiPassport do
  let(:birth_place) { 'NY' }
  let(:passport_expiration) { DateTime.now.advance(years: 1).strftime('%Y-%m-%d') }
  let(:passport_issued) { '2020-01-01' }
  let(:issuing_country_code) { 'USA' }
  let(:nationality_code) { 'USA' }
  let(:mrz) { 'MRZ123456789' }
  let(:document_type_received) { 'passport' }
  let(:pii) do
    {
      birth_place:,
      passport_expiration:,
      passport_issued:,
      issuing_country_code:,
      nationality_code:,
      mrz:,
      document_type_received:,
    }
  end
  subject(:doc_pii_passport) { Idv::DocPiiPassport.new(pii:) }

  context 'when pii is valid' do
    it 'is valid' do
      expect(subject).to be_valid
    end
  end

  context 'when mrz is missing' do
    let(:mrz) { nil }

    it 'is not valid' do
      expect(subject).not_to be_valid
      expect(subject.errors[:mrz]).to include(
        I18n.t('doc_auth.errors.general.no_liveness'),
      )
    end
  end

  context 'when issuing_country_code is not USA' do
    let(:issuing_country_code) { 'CAN' }

    it 'is not valid' do
      expect(subject).not_to be_valid
      expect(subject.errors[:issuing_country_code]).to include(
        I18n.t('doc_auth.errors.general.no_liveness'),
      )
    end
  end

  context 'when passport_expiration is in the past' do
    let(:passport_expiration) { DateTime.now.advance(years: -1).strftime('%Y-%m-%d') }

    it 'is not valid' do
      expect(subject).not_to be_valid
      expect(subject.errors[:passport_expiration]).to include(
        I18n.t('doc_auth.errors.general.no_liveness'),
      )
    end
  end

  context 'when document_type_received is passport_card' do
    let(:document_type_received) { 'passport_card' }

    it 'is not valid' do
      expect(subject).not_to be_valid
      expect(subject.errors[:document_type_received]).to include(
        I18n.t('doc_auth.errors.general.no_liveness'),
      )
    end
  end
end
