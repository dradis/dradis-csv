module Dradis::Plugins::CSV
  # Converts between the column mapper's form structure and persisted
  # Mapping records, one per entity (issue/evidence), so a CSV format only
  # needs to be mapped once: #save is the forward direction (form ->
  # records), .selections_for is the reverse (records -> form) used to
  # prefill the mapper on a later upload of the same format.
  class MappingBuilder
    # Mapper column types that produce fields for each entity: identifier
    # columns are stored with the issue mapping, node columns with evidence.
    ENTITY_TYPES = {
      issue: %w[issue identifier],
      evidence: %w[evidence node]
    }.freeze

    # Inverts the stored mapping fields back into the mapper form structure:
    # one { type:, field: } entry per header, in header order.
    def self.selections_for(headers:, destination:)
      headers = Array(headers)

      stored_fields = %i[issue evidence].flat_map do |entity|
        source = Dradis::Plugins::CSV.mapping_source(headers: headers, entity: entity)
        mapping = Dradis::Plugins::CSV.get_mapping(source: source, destination: destination)

        mapping ? mapping.mapping_fields.map { |field| [entity, field] } : []
      end

      headers.map do |header|
        normalized = Dradis::Plugins::CSV.normalize_header(header)
        entity, field = stored_fields.find { |_entity, f| f.source_field == normalized }

        case field&.destination_field
        when nil
          { type: 'skip' }
        when Mapping::IDENTIFIER_FIELD
          { type: 'identifier' }
        when Mapping::NODE_LABEL_FIELD
          { type: 'node' }
        else
          { type: entity.to_s, field: field.destination_field }
        end
      end
    end

    attr_reader :column_mappings, :destination, :headers

    # column_mappings is the mapper form submission, keyed by column index:
    #   {
    #     '0' => { 'type' => 'node' },
    #     '1' => { 'type' => 'issue', 'field' => 'Title' },
    #     '2' => { 'type' => 'identifier' },
    #     '3' => { 'type' => 'evidence', 'field' => 'Port' }
    #   }
    def initialize(column_mappings:, destination:, headers:)
      @column_mappings = column_mappings
      @destination = destination
      @headers = Array(headers)
    end

    # Upserts so the saved mapping always matches the last confirmed import:
    # existing fields are replaced, and an entity mapping is removed when no
    # columns are assigned to that entity anymore.
    def save
      return if destination.blank?

      ::Mapping.transaction do
        %i[issue evidence].each do |entity|
          source = Dradis::Plugins::CSV.mapping_source(headers: headers, entity: entity)
          mapping = ::Mapping.find_by(component: component, source: source, destination: destination)
          fields = fields_for(entity)

          if fields.empty?
            mapping&.destroy
            next
          end

          mapping ||= ::Mapping.create!(component: component, source: source, destination: destination)
          mapping.mapping_fields.destroy_all
          fields.each { |attributes| mapping.mapping_fields.create!(attributes) }
        end
      end
    end

    private

    def component
      Dradis::Plugins::CSV.component
    end

    def fields_for(entity)
      types = ENTITY_TYPES.fetch(entity)

      column_mappings.filter_map do |index, assignment|
        next unless types.include?(assignment['type'])

        header = Dradis::Plugins::CSV.normalize_header(headers[index.to_i])
        next if header.blank?

        destination_field =
          case assignment['type']
          when 'identifier' then Mapping::IDENTIFIER_FIELD
          when 'node'       then Mapping::NODE_LABEL_FIELD
          else
            next if assignment['field'].blank?

            assignment['field']
          end

        {
          source_field: header,
          content: "{{ csv[#{header}] }}",
          destination_field: destination_field
        }
      end
    end
  end
end
