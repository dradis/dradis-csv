require 'digest'

module Dradis::Plugins::CSV
  # Unlike other integrations, CSV files don't have a fixed structure, so the
  # list of sources can't be defined upfront. Instead, a new source is
  # registered every time a user maps a new CSV format (i.e. a new set of
  # column headers) through the column mapper (see MappingBuilder).
  #
  # The empty constants keep the interface expected by
  # Dradis::Plugins::Mappings::Base, while the class methods below override
  # its constant-backed defaults with database-backed lookups.
  module Mapping
    DEFAULT_MAPPING = {}.freeze
    SOURCE_FIELDS = {}.freeze

    # Reserved destination fields that carry row metadata instead of entity
    # content. They're stored alongside the content fields but are excluded
    # from the entity text during import.
    IDENTIFIER_FIELD = 'plugin_id'.freeze
    NODE_LABEL_FIELD = 'node_label'.freeze
  end

  def self.default_mapping(_source)
    {}
  end

  # Signals that sources are created on upload and can't be defined upfront
  # (e.g. so the Mappings Manager doesn't offer manual mapping creation).
  def self.dynamic_mapping_sources?
    true
  end

  def self.mapping_sources
    ::Mapping.where(component: component).distinct.pluck(:source).map(&:to_sym)
  end

  # The source name for a CSV format: a digest of its normalized headers plus
  # the entity (issue/evidence) the mapping populates. Headers are sorted so
  # reordering columns doesn't produce a new source.
  def self.mapping_source(headers:, entity:)
    normalized = Array(headers).map { |header| normalize_header(header) }.sort

    "csv_#{Digest::MD5.hexdigest(normalized.join(','))[0, 8]}_#{entity}"
  end

  def self.normalize_header(header)
    header.to_s.delete(" \t\r\n")
  end

  def self.source_fields(source)
    ::MappingField.
      joins(:mapping).
      where(mappings: { component: component, source: source.to_s }).
      distinct.
      pluck(:source_field)
  end
end
