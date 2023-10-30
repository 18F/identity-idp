# frozen_string_literal: true

class SimpleFormTestController < ActionController::Base
  def index
    @user = User.create
  end

  def update
    puts params.inspect
  end
end
