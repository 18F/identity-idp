# frozen_string_literal: true

module Test
  class FakeSocureConfig
    include ActiveModel::Model
    include ActiveModel::Attributes
    include ActiveModel::AttributeAssignment

    attribute :name, :string
    attribute :body, :string

    def pretty_name
      name.gsub(/\W+/, ' ').titlecase
    end
  end
end
