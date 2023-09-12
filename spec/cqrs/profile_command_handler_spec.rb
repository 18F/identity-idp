require 'spec_helper'

RSpec.describe ProfileCommandHandler do
  context AddProfile do
    let(:profile_aggregate_id) { Sequent.new_uuid }

    it 'creates a profile when valid input' do
      when_command AddProfile.new(
        aggregate_id: profile_aggregate_id,
      )
      then_events ProfileCreated.new(
        aggregate_id: profile_aggregate_id,
        sequence_number: 1,
      )
    end
  end
end
