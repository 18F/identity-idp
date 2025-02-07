# frozen_string_literal: true

class OutdatedAbTestAssignmentCleanupJob < ApplicationJob
  queue_as :low

  def perform
    AbTestAssignment.where.not(experiment: configured_experiments).in_batches.delete_all
  end

  private

  def configured_experiments
    AbTests.all.values.map(&:experiment_name)
  end
end
