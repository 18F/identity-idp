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
      create(
        :document_capture_session, passport_status: 'not_requested',
                                   document_type_requested: nil
      )
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
          'updated_at',
          'created_at',
        )
      end

      let(:passport_attrs) do
        passport_session.attributes.except(
          'document_type_requested',
          'updated_at',
          'created_at',
        )
      end

      it 'does not change other attributes' do
        task.execute

        verify_attributes(state_id_card_session, true)
        verify_attributes(passport_session, true)
        verify_attributes(no_passport_status_session, false)
        verify_attributes(already_backfilled_session, false)
      end
    end
  end

  describe 'document_capture_sessions:rollback_backfill_document_type_requested' do
    subject(:task) { Rake::Task['document_capture_sessions:rollback_backfill_document_type_requested'] }

    before do
      Rake::Task['document_capture_sessions:rollback_backfill_document_type_requested'].reenable
    end

    let!(:backfilled_state_id_card_session) do
      create(
        :document_capture_session,
        passport_status: 'not_requested',
        document_type_requested: Idp::Constants::DocumentTypes::STATE_ID_CARD,
      )
    end

    let!(:backfilled_passport_session) do
      create(
        :document_capture_session,
        passport_status: 'requested',
        document_type_requested: Idp::Constants::DocumentTypes::PASSPORT,
      )
    end

    let!(:no_passport_status_session) do
      create(
        :document_capture_session,
        passport_status: nil,
        document_type_requested: Idp::Constants::DocumentTypes::PASSPORT,
      )
    end

    let!(:already_nil_document_type_session) do
      create(:document_capture_session, passport_status: 'requested', document_type_requested: nil)
    end

    it 'resets document_type_requested only for backfilled document capture sessions' do
      task.execute

      verify_attributes(backfilled_state_id_card_session, false)
      verify_attributes(backfilled_passport_session, false)
      verify_attributes(no_passport_status_session, true)
      verify_attributes(already_nil_document_type_session, false)
    end
  end

  def verify_attributes(session, updated = false)
    orig_document_type_requested = session.document_type_requested
    orig_updated_at = session.updated_at
    orig_created_at = session.created_at

    # timestamps excepted due CI nanoseconds mismatch
    expect(session.attributes.except('document_type_requested', 'updated_at', 'created_at'))
      .to eq(
        session.reload.attributes.except('document_type_requested', 'updated_at', 'created_at'),
      )
    expect(session.updated_at).to be_within(1.second).of(orig_updated_at)
    expect(session.created_at).to be_within(1.second).of(orig_created_at)
    if updated
      expect(session.document_type_requested).not_to eq(orig_document_type_requested)
    else
      expect(session.document_type_requested).to eq(orig_document_type_requested)
    end
  end
end
