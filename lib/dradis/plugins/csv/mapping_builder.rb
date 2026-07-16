module Dradis::Plugins::CSV
  # Persists the column assignments submitted through the column mapper as
  # Mapping records, one per entity (issue/evidence), so future uploads of
  # the same CSV format can be imported without mapping it again.
  class MappingBuilder
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
      column_mappings.filter_map do |index, assignment|
        header = Dradis::Plugins::CSV.normalize_header(headers[index.to_i])
        next if header.blank?

        attributes = {
          source_field: header,
          content: "{{ csv[#{header}] }}"
        }

        case assignment['type']
        when entity.to_s
          next if assignment['field'].blank?

          attributes.merge(destination_field: assignment['field'])
        when 'identifier'
          attributes.merge(destination_field: Mapping::IDENTIFIER_FIELD) if entity == :issue
        when 'node'
          attributes.merge(destination_field: Mapping::NODE_LABEL_FIELD) if entity == :evidence
        end
      end
    end
  end
end
