class ArcgisTokenJob < ApplicationJob
  queue_as :default

  attr_accessor :token_keeper
  def initialize(token_keeper = nil)
    @token_keeper = token_keeper || ArcgisApi::TokenKeeper.new(nil, nil, nil)
  end

  def perform
    token_keeper.retrieve_token
  end
end
