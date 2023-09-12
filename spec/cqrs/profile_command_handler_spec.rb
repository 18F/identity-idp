require 'spec_helper'

RSpec.describe ProfileCommandHandler do
  context AddProfile do
    let(:aggregate_id) { Sequent.new_uuid }

    before :each do
      Sequent.configuration.command_handlers = [ProfileCommandHandler.new]
    end

    it 'creates a profile when valid input' do
      # create profile
      command = AddProfile.new(aggregate_id: aggregate_id)

      Sequent.aggregate_repository.add_aggregate(
        ProfileAggregate.new(command),
      )

      aggregate = Sequent.aggregate_repository.load_aggregate(command.aggregate_id, ProfileAggregate)
      expect(aggregate).to be_present
      expect(aggregate.id).to eq(aggregate_id)

      # mint the profile
      minted_at = 1.day.ago
      mint_command = MintProfile.new(
        aggregate_id: aggregate_id,
        minted_at: minted_at,
      )

      Sequent.command_service.execute_commands(mint_command)

      aggregate = Sequent.aggregate_repository.load_aggregate(
        mint_command.aggregate_id,
        ProfileAggregate,
      )
      expect(aggregate).to be_present
      # binding.pry
      # expect(aggregate.minted_at).to eq(minted_at)

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
