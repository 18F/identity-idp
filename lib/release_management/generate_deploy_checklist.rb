# rubocop:disable Rails/Output, Rails/Date

require 'erb'
require 'date'

module ReleaseManagement
  class GenerateDeployChecklist
    def call
      prompt_user_for_checklist_values
      template = File.read('lib/release_management/deploy_checklist.md.erb')
      puts "\n\nAdd the following the wiki under RC #{rc_number}:\n\n"
      puts ERB.new(template).result(binding)
    end

    private

    attr_accessor :rc_number, :previous_rc_number, :rc_branch_name, :previous_rc_branch_name,
                  :branch_date, :staging_deploy_date, :production_deploy_date

    # :reek:TooManyStatements
    def prompt_user_for_checklist_values
      prompt_for_rc_number
      prompt_for_previous_rc_number
      prompt_for_rc_branch_name
      prompt_for_previous_rc_branch_name
      prompt_for_branch_date
      prompt_for_staging_deploy_date
      prompt_for_production_deploy_date
    end

    def prompt_for_rc_number
      prompt_user_for(
        :rc_number,
        prompt: 'What is the RC number for this deploy (e.g. 81)',
      )
    end

    def prompt_for_previous_rc_number
      default_value = rc_number.to_i - 1
      prompt_user_for(
        :previous_rc_number,
        prompt: 'What is the RC number for the previous RC',
        default: default_value,
      )
    end

    def prompt_for_rc_branch_name
      default_value = "stages/rc-#{next_thursday.strftime('%Y-%m-%d')}"
      prompt_user_for(
        :rc_branch_name,
        prompt: 'What is the RC branch name',
        default: default_value,
      )
    end

    def prompt_for_previous_rc_branch_name
      last_deploy_date = next_thursday - 14
      default_value = "stages/rc-#{last_deploy_date.strftime('%Y-%m-%d')}"
      prompt_user_for(
        :previous_rc_branch_name,
        prompt: 'What was the previous RC branch name',
        default: default_value,
      )
    end

    def prompt_for_branch_date
      default_branch_date = next_thursday - 3
      default_value = default_branch_date.strftime('%A, %B %d, %Y')
      prompt_user_for(
        :branch_date,
        prompt: 'When will you create the new branch',
        default: default_value,
      )
    end

    def prompt_for_staging_deploy_date
      default_staging_deploy_date = next_thursday - 2
      default_value = default_staging_deploy_date.strftime('%A, %B %d, %Y')
      prompt_user_for(
        :staging_deploy_date,
        prompt: 'When will you deploy staging',
        default: default_value,
      )
    end

    def prompt_for_production_deploy_date
      default_production_deploy_date = next_thursday
      default_value = default_production_deploy_date.strftime('%A, %B %d, %Y')
      prompt_user_for(
        :production_deploy_date,
        prompt: 'When will you deploy production',
        default: default_value,
      )
    end

    # :reek:TooManyStatements
    def prompt_user_for(name, prompt:, default: nil)
      prompt = "#{prompt} (leave blank for #{default})" if default
      print "#{prompt}? "
      instance_variable_name = "@#{name}"
      instance_variable_set(instance_variable_name, gets.strip)
      return unless blank?(instance_variable_get(instance_variable_name))
      return prompt_user_for(name, prompt: prompt, default: default) if default.nil?
      instance_variable_set(instance_variable_name, default)
    end

    # :reek:DuplicateMethodCall
    def next_thursday
      days_until_thursday = (4 - Date.today.wday).abs
      Date.today + days_until_thursday
    end

    def blank?(string)
      string.nil? || string.empty? # rubocop:disable Rails/Blank
    end
  end
end

ReleaseManagement::GenerateDeployChecklist.new.call

# rubocop:enable Rails/Output, Rails/Date
