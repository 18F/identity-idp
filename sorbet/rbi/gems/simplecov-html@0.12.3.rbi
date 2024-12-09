# typed: true

# DO NOT EDIT MANUALLY
# This is an autogenerated file for types exported from the `simplecov-html` gem.
# Please instead update this file by running `bin/tapioca gem simplecov-html`.


# source://simplecov-html//lib/simplecov-html.rb#16
module SimpleCov
  class << self
    # source://simplecov/0.22.0/lib/simplecov.rb#174
    def at_exit_behavior; end

    # source://simplecov/0.22.0/lib/simplecov.rb#170
    def clear_result; end

    # source://simplecov/0.22.0/lib/simplecov.rb#86
    def collate(result_filenames, profile = T.unsafe(nil), ignore_timeout: T.unsafe(nil), &block); end

    # source://simplecov/0.22.0/lib/simplecov.rb#223
    def exit_and_report_previous_error(exit_status); end

    # source://simplecov/0.22.0/lib/simplecov.rb#200
    def exit_status_from_exception; end

    # source://simplecov/0.22.0/lib/simplecov.rb#28
    def external_at_exit; end

    # source://simplecov/0.22.0/lib/simplecov.rb#28
    def external_at_exit=(_arg0); end

    # source://simplecov/0.22.0/lib/simplecov.rb#28
    def external_at_exit?; end

    # source://simplecov/0.22.0/lib/simplecov.rb#131
    def filtered(files); end

    # source://simplecov/0.22.0/lib/simplecov.rb#268
    def final_result_process?; end

    # source://simplecov/0.22.0/lib/simplecov.rb#142
    def grouped(files); end

    # source://simplecov/0.22.0/lib/simplecov.rb#162
    def load_adapter(name); end

    # source://simplecov/0.22.0/lib/simplecov.rb#158
    def load_profile(name); end

    # source://simplecov/0.22.0/lib/simplecov.rb#24
    def pid; end

    # source://simplecov/0.22.0/lib/simplecov.rb#24
    def pid=(_arg0); end

    # source://simplecov/0.22.0/lib/simplecov.rb#213
    def previous_error?(error_exit_status); end

    # source://simplecov/0.22.0/lib/simplecov.rb#248
    def process_result(result); end

    # source://simplecov/0.22.0/lib/simplecov.rb#233
    def process_results_and_report_error; end

    # source://simplecov/0.22.0/lib/simplecov.rb#229
    def ready_to_process_results?; end

    # source://simplecov/0.22.0/lib/simplecov.rb#101
    def result; end

    # source://simplecov/0.22.0/lib/simplecov.rb#124
    def result?; end

    # source://simplecov/0.22.0/lib/simplecov.rb#256
    def result_exit_status(result); end

    # source://simplecov/0.22.0/lib/simplecov.rb#296
    def round_coverage(coverage); end

    # source://simplecov/0.22.0/lib/simplecov.rb#186
    def run_exit_tasks!; end

    # source://simplecov/0.22.0/lib/simplecov.rb#24
    def running; end

    # source://simplecov/0.22.0/lib/simplecov.rb#24
    def running=(_arg0); end

    # source://simplecov/0.22.0/lib/simplecov.rb#48
    def start(profile = T.unsafe(nil), &block); end

    # source://simplecov/0.22.0/lib/simplecov.rb#276
    def wait_for_other_processes; end

    # source://simplecov/0.22.0/lib/simplecov.rb#285
    def write_last_run(result); end

    private

    # source://simplecov/0.22.0/lib/simplecov.rb#399
    def adapt_coverage_result; end

    # source://simplecov/0.22.0/lib/simplecov.rb#371
    def add_not_loaded_files(result); end

    # source://simplecov/0.22.0/lib/simplecov.rb#302
    def initial_setup(profile, &block); end

    # source://simplecov/0.22.0/lib/simplecov.rb#363
    def lookup_corresponding_ruby_coverage_name(criterion); end

    # source://simplecov/0.22.0/lib/simplecov.rb#425
    def make_parallel_tests_available; end

    # source://simplecov/0.22.0/lib/simplecov.rb#434
    def probably_running_parallel_tests?; end

    # source://simplecov/0.22.0/lib/simplecov.rb#388
    def process_coverage_result; end

    # source://simplecov/0.22.0/lib/simplecov.rb#410
    def remove_useless_results; end

    # source://simplecov/0.22.0/lib/simplecov.rb#420
    def result_with_not_loaded_files; end

    # source://simplecov/0.22.0/lib/simplecov.rb#314
    def start_coverage_measurement; end

    # source://simplecov/0.22.0/lib/simplecov.rb#349
    def start_coverage_with_criteria; end
  end
end

# source://simplecov-html//lib/simplecov-html.rb#17
module SimpleCov::Formatter
  class << self
    # source://simplecov/0.22.0/lib/simplecov/default_formatter.rb#7
    def from_env(env); end
  end
end

# source://simplecov-html//lib/simplecov-html.rb#18
class SimpleCov::Formatter::HTMLFormatter
  # @return [HTMLFormatter] a new instance of HTMLFormatter
  #
  # source://simplecov-html//lib/simplecov-html.rb#19
  def initialize; end

  # @return [Boolean]
  #
  # source://simplecov-html//lib/simplecov-html.rb#38
  def branchable_result?; end

  # source://simplecov-html//lib/simplecov-html.rb#23
  def format(result); end

  # @return [Boolean]
  #
  # source://simplecov-html//lib/simplecov-html.rb#45
  def line_status?(source_file, line); end

  # source://simplecov-html//lib/simplecov-html.rb#34
  def output_message(result); end

  private

  # source://simplecov-html//lib/simplecov-html.rb#64
  def asset_output_path; end

  # source://simplecov-html//lib/simplecov-html.rb#72
  def assets_path(name); end

  # source://simplecov-html//lib/simplecov-html.rb#97
  def coverage_css_class(covered_percent); end

  # source://simplecov-html//lib/simplecov-html.rb#93
  def covered_percent(percent); end

  # Returns a table containing the given source files
  #
  # source://simplecov-html//lib/simplecov-html.rb#84
  def formatted_file_list(title, source_files); end

  # Returns the html for the given source_file
  #
  # source://simplecov-html//lib/simplecov-html.rb#77
  def formatted_source_file(source_file); end

  # Return a (kind of) unique id for the source file given. Uses SHA1 on path for the id
  #
  # source://simplecov-html//lib/simplecov-html.rb#118
  def id(source_file); end

  # source://simplecov-html//lib/simplecov-html.rb#130
  def link_to_source_file(source_file); end

  # source://simplecov-html//lib/simplecov-html.rb#60
  def output_path; end

  # source://simplecov-html//lib/simplecov-html.rb#126
  def shortened_filename(source_file); end

  # source://simplecov-html//lib/simplecov-html.rb#107
  def strength_css_class(covered_strength); end

  # Returns the an erb instance for the template of given name
  #
  # source://simplecov-html//lib/simplecov-html.rb#56
  def template(name); end

  # source://simplecov-html//lib/simplecov-html.rb#122
  def timeago(time); end
end

# source://simplecov-html//lib/simplecov-html/version.rb#6
SimpleCov::Formatter::HTMLFormatter::VERSION = T.let(T.unsafe(nil), String)
