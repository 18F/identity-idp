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

      aggregate =
        Sequent.aggregate_repository.load_aggregate(
          command.aggregate_id, ProfileAggregate
        )
      expect(aggregate).to be_present
      expect(aggregate.id).to eq(aggregate_id)

      a_time = Time.zone.now
      unencrypted_payload = {
        foo: :bar,
      }.to_json

      when_command MintProfile.new(
        aggregate_id: aggregate_id,
        minted_at: a_time,
        unencrypted_payload: unencrypted_payload,
      )
      then_events(
        ProfileCreated.new(
          aggregate_id: aggregate_id,
          sequence_number: 1,
        ),
        ProfileMinted.new(
          aggregate_id: aggregate_id,
          minted_at: a_time,
          unencrypted_payload: unencrypted_payload,
          sequence_number: 2,
        ),
      )
    end
  end
end
