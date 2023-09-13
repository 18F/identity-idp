require 'spec_helper'
# require_relative '../../app/projectors/profile_projector'

Rspec.describe ProfileProjector do
  let(:aggregate_id) { Sequent.new_uuid }
  let(:profile_projector) { ProfileProjector.new }
  let(:profile_added) { ProfileAdded.new(aggregate_id: aggregate_id, sequence_number: 1) }

  context ProfileAdded do
    it 'creates a projection' do
      profile_projector.handle_message(profile_added)
      expect(ProfileRecord.count).to eq(1)
      record = ProfileRecord.first
      expect(record.aggregate_id).to eq(aggregate_id)
    end
  end

  context ProfileMinted do
    let(:profile_title_changed) do
      ProfileMinted.new(aggregate_id: aggregate_id, title: 'ben en kim', sequence_number: 2)
    end

    before { profile_projector.handle_message(profile_added) }

    it 'updates a projection' do
      profile_projector.handle_message(profile_title_changed)
      expect(ProfileRecord.count).to eq(1)
      record = ProfileRecord.first
      expect(record.title).to eq('ben en kim')
    end
  end
end
