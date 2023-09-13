class ProfileAggregate < Sequent::AggregateRoot
  def initialize(command)
    super(command.aggregate_id)
    apply ProfileCreated
  end

  def mint(minted_at)
    apply(ProfileMinted, minted_at: minted_at)
  end

  on ProfileCreated do
  end

  on ProfileMinted do |event|
    @minted_at = event.minted_at
  end
end
