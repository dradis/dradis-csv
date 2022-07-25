module Dradis::Plugins::CSV
  class MappingImportJob < ApplicationJob
    queue_as :dradis_project

    # mappings hash:
    # The key is the column index, while the value is a hash containing the type of resource (evidence/identifier/issue/node).
    # It's used to map a CSV header to a field in Dradis (only for evidence and issues).
    #
    # e.g.
    # {
    #   '0' => { 'type' => 'node' },
    #   '1' => { 'type' => 'issue', 'field' => 'Title' },
    #   '2' => { 'type' => 'identifier' },
    #   '3' => { 'type' => 'evidence', 'field' => 'Port' }
    # }
    def perform(file:, mappings:, project_id:, uid:)
      @logger = Log.new(uid: uid)
      @logger.write { "Job id is #{job_id}." }
      @logger.write { 'Worker process starting background task.' }

      # Converts mapping hash into groups of arrays
      # {
      #   'node' => [['0', { 'type' => 'node' }]],
      #   'identifier' => [['2', { 'type' => 'identifier' }]]
      # }
      @mappings_groups = mappings.group_by { |index, mapping| mapping['type'] }
      @id_index = Integer(@mappings_groups['identifier']&.first&.first, exception: false)

      unless @id_index
        @logger.fatal('Unique Identifier doesn\'t exist, please choose a column as the Unique Identifier.')
        return
      end

      @id_index = @id_index.to_i
      @file = file
      @project = Project.find(project_id)

      import_csv!

      @logger.write { 'Worker process completed.' }
    end

    private

    def content_service
      @content_service ||= Dradis::Plugins::ContentService::Base.new(
        project: @project,
        plugin: Dradis::Plugins::CSV
      )
    end

    def import_csv!
      @node_index = Integer(@mappings_groups['node']&.first&.first, exception: false)
      @issue_mappings = @mappings_groups['issue'] || []
      @evidence_mappings = @mappings_groups['evidence'] || []

      CSV.foreach(@file, headers: true) do |row|
        process_row(row)
      end
    end

    def process_row(row)
      id = row[@id_index]

      @logger.info { "\t => Creating new issue (plugin_id: #{id})" }
      issue_text = build_text(mappings: @issue_mappings, row: row)
      issue = content_service.create_issue(text: issue_text, id: id)

      node_label = row[@node_index]

      if node_label.present?
        @logger.info { "\t\t => Processing node: #{node_label}" }
        node = content_service.create_node(label: node_label, type: :host)

        @logger.info{ "\t\t => Creating evidence: (node: #{node_label}, plugin_id: #{id})" }
        evidence_content = build_text(mappings: @evidence_mappings, row: row)
        content_service.create_evidence(issue: issue, node: node, content: evidence_content)
      end
    end

    def build_text(mappings:, row:)
      mappings.map do |index, mapping|
        next if @project.report_template_properties && mapping['field'].blank?

        field_name = @project.report_template_properties ? mapping['field'] : row.headers[index.to_i].delete(" \t\r\n")
        field_value = row[index.to_i]
        "#[#{field_name}]#\n#{field_value}"
      end.compact.join("\n\n")
    end
  end
end
