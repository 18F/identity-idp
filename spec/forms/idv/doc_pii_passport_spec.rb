# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Idv::DocPiiPassport do
  let(:birth_place) { 'NY' }
  let(:passport_expiration) { DateTime.now.advance(years: 1).strftime('%Y-%m-%d') }
  let(:passport_issued) { '2020-01-01' }
  let(:issuing_country_code) { 'USA' }
  let(:nationality_code) { 'USA' }
  let(:mrz) { 'MRZ123456789' }
  let(:id_doc_type) { 'passport' }
  let(:pii) do
    {
      birth_place:,
      passport_expiration:,
      passport_issued:,
      issuing_country_code:,
      nationality_code:,
      mrz:,
      id_doc_type:,
    }
  end
  subject(:doc_pii_passport) { described_class.new(pii:) }

  context 'when pii is valid' do
    it 'is valid' do
      expect(subject).to be_valid
    end
  end

  context 'when birth_place is missing' do
    let(:birth_place) { nil }

    it 'is not valid' do
      expect(subject).not_to be_valid
      expect(subject.errors[:birth_place]).to include(
        I18n.t('doc_auth.errors.general.no_liveness'),
      )
    end
  end

  context 'when passport_issued is missing' do
    let(:passport_issued) { nil }

    it 'is not valid' do
      expect(subject).not_to be_valid
      expect(subject.errors[:passport_issued]).to include(
        I18n.t('doc_auth.errors.general.no_liveness'),
      )
    end
  end

  context 'when nationality_code is missing' do
    let(:nationality_code) { '' }

    it 'is not valid' do
      expect(subject).not_to be_valid
      expect(subject.errors[:nationality_code]).to include(
        I18n.t('doc_auth.errors.general.no_liveness'),
      )
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

  context 'when nationality_code is not USA' do
    let(:nationality_code) { 'CAN' }

    it 'is not valid' do
      expect(subject).not_to be_valid
      expect(subject.errors[:nationality_code]).to include(
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

  context 'when id_doc_type is passport_card' do
    let(:id_doc_type) { 'passport_card' }

    it 'is not valid' do
      expect(subject).not_to be_valid
      expect(subject.errors[:id_doc_type]).to include(
        I18n.t('doc_auth.errors.general.no_liveness'),
      )
    end
  end
end
