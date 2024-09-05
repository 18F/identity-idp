# frozen_string_literal: true

class OutdatedAbTestAssignmentCleanupJob < ApplicationJob
  queue_as :low

  def perform
    AbTestAssignment.where.not(experiment: active_experiments).destroy_all
  end

  private

  def active_experiments
    AbTests.all.values.map(&:experiment_name)
  end
end
