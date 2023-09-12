class ProfileAggregate < Sequent::AggregateRoot
  def initialize(command)
    super(command.aggregate_id)
    apply ProfileCreated
  end

  on ProfileCreated do
    binding.pry
  end
end
