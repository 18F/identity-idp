class ProfileCommandHandler < Sequent::CommandHandler
  on AddProfile do |command|
    repository.add_aggregate(ProfileAggregate.new(command))
  end
end
