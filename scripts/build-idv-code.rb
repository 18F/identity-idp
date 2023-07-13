#!/usr/bin/env ruby
Dir.chdir(File.dirname(__FILE__)) { require 'bundler/setup' }

require 'active_support/core_ext/string'
require 'action_controller'
require 'action_view'
require 'yaml'

def get_params_schema_for_event(event, document)
  return if !event[:params]

  schema = event[:params]

  has_ref = !!schema[:$ref]
  has_type = !!schema[:type]

  if !has_ref && !has_type
    # This might be shorthand, assume it's an object
    schema = {
      type: 'object',
      properties: schema,
    }
  end

  resolve_schema(schema, document).merge(
    {
      title: "#{event[:name].to_s.camelize}Params",
    },
  )
end

def resolve_schema(schema, document)
  ref = schema[:$ref]

  if ref
    raise "Invalid $ref: #{ref}" unless ref.start_with?('#!/')

    path = ref.sub('#!/', '').split('/').map { |s| s.to_sym }
    schema_at_path = document.dig(*path)

    if !schema_at_path
      raise "Invalid $ref: #{path}"
    end

    return resolve_schema(schema_at_path, document)
  end

  if schema[:type] == 'object' && schema.has_key?(:properties)
    new_properties = {}
    schema[:properties].each_pair do |name, property_schema|
      if property_schema.nil?
        property_schema = { type: 'string' }
      end
      new_properties[name] = resolve_schema(property_schema, document)
    end
    schema.merge(properties: new_properties)
  elsif schema[:type] == 'array' && schema[:items]
    schema.merge(
      {
        items: resolve_schema(schema[:items], document),
      },
    )
  else
    schema
  end
end

WIDTH = 80

document = YAML.safe_load_file(ARGV[0], symbolize_names: true)

events = document[:events].map do |name, event|
  {
    name:,
    **event,
  }
end.sort_by { |a| a[:name] }

param_structs = []
methods = []

events.each do |event|
  args = []
  rdoc = ActionController::Base.helpers.word_wrap(event[:description]).split("\n")

  params_schema = get_params_schema_for_event(event, document)

  if params_schema
    args << 'params'
    rdoc << "@param [#{params_schema[:title]}] params"

    properties = params_schema[:properties] || {}

    if properties.length == 0
      param_structs << "#{params_schema[:title]} = Struct.new"
    else
      param_structs << "#{params_schema[:title]} = Struct.new("
      properties.each_pair do |name, _schema|
        param_structs << "  :#{name},"
      end
      param_structs << '  keyword_init: true,'
      param_structs << ')'
    end

    param_structs << ''

    rdoc << "@return [#{params_schema[:title]}]"
  else
    rdoc << '@return [nil]'
  end

  rdoc.each do |line|
    methods << "# #{line}"
  end

  methods << "def #{event[:name]}#{ "(#{args.join(", ")})" unless args.empty? }"
  methods << "  #{args[0] || 'nil'}"
  methods << 'end'
  methods << ''
end

methods.pop # remove last blank line

lines = []
lines << "# 👋 This file was automatically generated. Please don't edit it by hand."
lines << ''
lines << 'module Idv::Events'

if !param_structs.empty?
  param_structs.each { |line| lines << "  #{line}".rstrip }
end

methods.each { |line| lines << "  #{line}".rstrip }

lines << 'end'

puts lines.join("\n")
