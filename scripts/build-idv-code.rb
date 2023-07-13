#!/usr/bin/env ruby
Dir.chdir(File.dirname(__FILE__)) { require 'bundler/setup' }

require 'active_support/core_ext/string'
require 'action_controller'
require 'action_view'
require 'yaml'

def resolve_schema(schema, document)
  return schema if !schema

  ref = schema[:ref]

  if ref
    raise "Invalid ref: #{ref}" unless ref.start_with?('#!/')
    path = ref.sub('#!/', '').split('/')
    return resolve_schema(document.dig(path), document)
  end

  if schema[:type] == 'object' && schema[:properties]
    schema.merge(
      {
        properties: schema[:properties].transform_values do |schema|
                      resolve_schema(schema, document)
                    end,
      },
    )
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

  if event[:params]
    args << 'params'
    params_type = "#{event[:name].to_s.camelize}Params"
    rdoc << "@param [#{params_type}] params"

    schema = if event[:params][:type]
               event[:params]
    else
      {
        type: 'object',
        properties: event[:params],
      }
    end

    schema = resolve_schema(schema, document)
    properties = schema[:properties] || {}

    if properties.length == 0
      param_structs << "#{params_type} = Struct.new()"
    else
      param_structs << "#{params_type} = Struct.new("
      properties.each_pair do |name, _schema|
        param_structs << "  :#{name},"
      end
      param_structs << '  keyword_init: true'
      param_structs << ')'
    end

    param_structs << ''

    rdoc << "@return [#{params_type}]"
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

lines = []
lines << "# 👋 This file was automatically generated. Please don't edit it by hand."
lines << ''
lines << 'module Idv::Events'
lines << ''

if !param_structs.empty?
  param_structs.each { |line| lines << "  #{line}" }
  lines << ''
end

methods.each { |line| lines << "  #{line}" }

lines << 'end'

puts lines.join("\n")
