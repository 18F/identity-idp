class ProfileCommandHandler < Sequent::CommandHandler
  on AddProfile do |command|
    repository.add_aggregate(ProfileAggregate.new(command))
  end

  on MintProfile do |command|
    do_with_aggregate(command, ProfileAggregate) do |profile_aggregate|
      profile_aggregate.mint(command.minted_at)
    end
  end
end
