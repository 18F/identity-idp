# This overrides the ActiveJob logger to be able to filter out raw
# unencrypted Devise tokens from the logs when password reset and
# confirmation emails are sent
ActiveSupport.on_load :active_job do
  module ActiveJob
    module Logging
      class LogSubscriber
        private

        def args_info(job)
          return '' unless job.arguments.any?

          ' with arguments: ' + filtered_job_arguments(job.arguments)
        end

        def filtered_job_arguments(arguments)
          if Figaro.env.log_all_active_job_arguments == 'true'
            converted_arguments(arguments).join(', ')
          elsif arguments.any? { |arg| arg.respond_to?(:to_global_id) }
            converted_arguments(arguments)[0..3].join(', ')
          else
            converted_arguments(arguments)[0..2].join(', ')
          end
        end

        def converted_arguments(arguments)
          arguments.map { |arg| arg.try(:to_global_id).try(:to_s) || arg.inspect }
        end
      end
    end
  end
end
