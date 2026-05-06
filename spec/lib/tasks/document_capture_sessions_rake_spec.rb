require 'rails_helper'
require 'rake'

RSpec.describe 'document_capture_sessions rake tasks', type: :task do
  before do
    Rake.application.rake_require 'tasks/backfill_document_type_requested'
    Rake::Task.define_task(:environment)
  end

  describe 'document_capture_sessions:backfill_document_type_requested' do
    subject(:task) { Rake::Task['document_capture_sessions:backfill_document_type_requested'] }

    before do
      Rake::Task['document_capture_sessions:backfill_document_type_requested'].reenable
    end

    let!(:state_id_card_session) do
      create(:document_capture_session, passport_status: 'not_requested', document_type_requested: nil)
    end

    let!(:passport_session) do
      create(:document_capture_session, passport_status: 'requested', document_type_requested: nil)
    end

    let!(:no_passport_status_session) do
      create(:document_capture_session, passport_status: nil, document_type_requested: nil)
    end

    let!(:already_backfilled_session) do
      create(:document_capture_session, passport_status: 'requested', document_type_requested: Idp::Constants::DocumentTypes::PASSPORT)
    end

    it 'backfills document_type_requested for eligible document capture sessions' do
      subject.execute

      expect(state_id_card_session.reload.document_type_requested).to eq(
        Idp::Constants::DocumentTypes::STATE_ID_CARD,
      )
      expect(passport_session.reload.document_type_requested).to eq(
        Idp::Constants::DocumentTypes::PASSPORT,
      )
      expect(no_passport_status_session.reload.document_type_requested).to be_nil
      expect(already_backfilled_session.reload.document_type_requested).to eq(
        Idp::Constants::DocumentTypes::PASSPORT,
      )
    end
  end
end
