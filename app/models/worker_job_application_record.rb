class WorkerJobApplicationRecord < ActiveRecord::Base
  self.abstract_class = true

  connects_to database: { writing: :worker_jobs, reading: :worker_jobs }
end
