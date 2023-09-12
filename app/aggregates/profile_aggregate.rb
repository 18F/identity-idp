class ProfileAggregate < Sequent::AggregateRoot
  def initialize(command)
    super(command.aggregate_id)
    apply ProfileCreated
  end

  on ProfileCreated do
  end

  on ProfileMinted do |event|
    @minted_at = event.minted_at
  end
end
