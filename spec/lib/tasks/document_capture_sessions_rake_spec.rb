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

    context 'ensure only document_type_requested is updated' do
      let(:state_id_attrs) do
        state_id_card_session.attributes.except(
          'document_type_requested',
        )
      end

      let(:passport_attrs) do
        passport_session.attributes.except(
          'document_type_requested',
        )
      end

      it 'does not change other attributes' do
        task.execute

        document_type_requested_orig = state_id_card_session.document_type_requested
        expect(state_id_attrs).to eq(
          state_id_card_session.reload.attributes.except(
            'document_type_requested',
          ),
        )
        expect(document_type_requested_orig).not_to eq(state_id_card_session.reload.document_type_requested)


        document_type_requested_orig = passport_session.document_type_requested
        expect(passport_attrs).to eq(
          passport_session.reload.attributes.except(
            'document_type_requested',
          ),
        )
        expect(document_type_requested_orig).not_to eq(passport_session.reload.document_type_requested)


        expect(no_passport_status_session.attributes).to eq(
          no_passport_status_session.reload.attributes
        )

        expect(already_backfilled_session.attributes).to eq(
          already_backfilled_session.reload.attributes
        )
      end
    end
  end
end
