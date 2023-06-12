class ArcgisTokenJob < ApplicationJob
  queue_as :default

  attr_reader :token_keeper
  def initialize(token_keeper: ArcgisApi::TokenKeeper.new)
    @token_keeper = token_keeper
  end

  def perform
    token_keeper.retrieve_token
  end
end
