class WorkerJobApplicationRecord < ActiveRecord::Base
  connects_to database: { writing: :worker_jobs, reading: :worker_jobs }
end
