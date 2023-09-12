class MintProfile < Sequent::Command
  attrs minted_at: Time
  validates_presence_of :minted_at
end
