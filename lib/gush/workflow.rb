require 'tree'
require 'securerandom'
require 'gush/metadata'
require 'gush/edge'
require 'gush/node'

module Gush
  class Workflow < Node
    include Gush::Metadata

    attr_accessor :nodes

    def initialize(name, options = {})
      @name = name
      @nodes = []
      configure unless options[:configure] == false
    end

    def configure
    end

    def find_job(name)
      @nodes.find { |node| node.name == name.to_s || node.class.to_s == name.to_s }
    end

    def finished?
      nodes.all?(&:finished)
    end

    def running?
      nodes.any?(&:enqueued)
    end

    def failed?
      nodes.any?(&:failed)
    end

    def run(klass, deps = {})
      node = klass.new(klass.to_s)

      deps_after = [*deps[:after]]
      deps_after.each do |dep|
        parent = find_job(dep)
        if parent.nil?
          raise "Job #{dep} does not exist in the graph. Register it first."
        end

        parent.connect_to(node)
        node.connect_from(parent)
      end

      deps_before = [*deps[:before]]
      deps_before.each do |dep|
        child = find_job(dep)
        if child.nil?
          raise "Job #{dep} does not exist in the graph. Register it first."
        end

        node.connect_to(child)
        child.connect_from(node)
      end

      @nodes << node
    end


    def to_json
      hash = {
        name: @name,
        klass: self.class.to_s,
        nodes: @nodes.map(&:as_json),
        edges: @nodes.flat_map { |node| node.edges.map(&:as_json) }.uniq
      }

      JSON.dump(hash)
    end

    def next_jobs
      @nodes.select(&:can_be_started?)
    end
  end
end