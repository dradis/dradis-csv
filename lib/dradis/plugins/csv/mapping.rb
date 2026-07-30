module Dradis::Plugins::CSV
  # Unlike other integrations, CSV files don't have a fixed structure, so the
  # list of sources can't be defined upfront. Instead, a new source is
  # registered every time a user maps a new CSV format (i.e. a new set of
  # column headers) through the column mapper (see MappingForm). The class
  # methods below give Dradis::Plugins::Mappings::Base's default,
  # constant-backed implementations (mapping_sources, source_fields,
  # default_mapping) database-backed overrides instead, so there's no
  # DEFAULT_MAPPING/SOURCE_FIELDS constant here for them to fall back to.
  module Mapping
    # Reserved destination fields that carry row metadata instead of entity
    # content. They're stored alongside the content fields but are excluded
    # from the entity text during import.
    IDENTIFIER_FIELD = 'plugin_id'.freeze
    NODE_LABEL_FIELD = 'node_label'.freeze
  end

  def self.default_mapping(_source)
    {}
  end

  # Excludes the reserved identifier/node fields from the destination field
  # list: they carry row metadata, not entity content (see Importer#mapped_fields,
  # which excludes them the same way when building the import template).
  def self.field_names(source:, destination: nil, field_type: 'destination')
    super.reject do |field|
      field_type == 'destination' &&
        [Mapping::IDENTIFIER_FIELD, Mapping::NODE_LABEL_FIELD].include?(field)
    end
  end

  # Whether a format matching these headers has already been mapped for this
  # destination, i.e. whether either its issue or evidence Mapping (or both)
  # was saved. Shared by Importer#import (to recognize a format on upload)
  # and UploadController (to skip the mapper for a recognized format).
  def self.mapping_exists?(headers:, destination:)
    sources = %i[issue evidence].map { |entity| mapping_source(headers: headers, entity: entity) }

    ::Mapping.exists?(component: component, source: sources, destination: destination)
  end

  def self.mapping_sources
    ::Mapping.where(component: component).distinct.pluck(:source).map(&:to_sym)
  end

  # The source name for a CSV format: the entity (issue/evidence) the mapping
  # populates, plus its normalized headers joined with '/', so the Mappings
  # Manager shows something recognizable (e.g. issue_severity/title) instead
  # of an opaque digest. Headers are sorted so reordering columns doesn't
  # produce a new source; any '/' inside a header name is replaced so it
  # can't be mistaken for the join separator. The entity prefix also lets
  # Importer.templates group sources by entity with a simple regex.
  def self.mapping_source(headers:, entity:)
    normalized = headers.map { |header| normalize_header(header).gsub('/', '-') }.sort

    "#{entity}_#{normalized.join('/')}"
  end

  def self.normalize_header(header)
    header.to_s.delete(" \t\r\n")
  end

  # We're building a dynamic source here since we can't rely on a fixed set of
  # sources unlike the other integrations.
  def self.sample(source)
    source_fields(source).index_with { |field| field }.to_json
  end

  def self.source_fields(source)
    ::MappingField.
      joins(:mapping).
      where(mappings: { component: component, source: source.to_s }).
      where.not(source_field: 'Custom Text').
      distinct.
      pluck(:source_field)
  end
end
