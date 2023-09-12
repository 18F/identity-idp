require 'spec_helper'

RSpec.describe ProfileCommandHandler do
  context AddProfile do
    let(:aggregate_id) { Sequent.new_uuid }

    it 'creates a profile when valid input' do
      command = AddProfile.new(aggregate_id: aggregate_id)

      Sequent.aggregate_repository.add_aggregate(
        ProfileAggregate.new(command),
      )

      aggregate = Sequent.aggregate_repository.load_aggregate(command.aggregate_id, ProfileAggregate)
      expect(aggregate).to be_present
      expect(aggregate.id).to eq(aggregate_id)

      a_time = Time.zone.now
      when_command MintProfile.new(
        aggregate_id: aggregate_id,
        minted_at: a_time,
      )
      then_events ProfileCreated.new(
        aggregate_id: aggregate_id,
        sequence_number: 1,
      )
    end
  end
end
