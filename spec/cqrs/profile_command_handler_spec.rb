require 'spec_helper'

RSpec.describe ProfileCommandHandler do
  context AddProfile do
    let(:aggregate_id) { Sequent.new_uuid }

    it 'creates a profile when valid input' do
      command = AddProfile.new(aggregate_id: aggregate_id)
      Sequent.aggregate_repository.add_aggregate(
        ProfileAggregate.new(command),
      )
      when_command AddProfile.new(
        aggregate_id: aggregate_id,
      )
      then_events ProfileCreated.new(
        aggregate_id: aggregate_id,
        sequence_number: 1,
      )
    end
  end
end
