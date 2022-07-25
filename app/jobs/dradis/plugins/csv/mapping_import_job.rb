module Dradis::Plugins::CSV
  class MappingImportJob < ApplicationJob
    queue_as :dradis_project

    # mappings hash:
    # The key is the column index, while the value is a hash containing the type of resource (evidence/issue/node).
    # It's used to map a CSV header to a field in Dradis (only for evidence and issues).
    #
    # e.g.
    # {
    #   '0' => { 'type' => 'node' },
    #   '1' => { 'type' => 'issue', 'field' => 'Title' },
    #   '2' => { 'type' => 'evidence', 'field' => 'Port' }
    # }
    def perform(file:, id_index:, mappings:, project_id:, uid:)
      @logger = Log.new(uid: uid)
      @logger.write { "Job id is #{job_id}." }
      @logger.write { 'Worker process starting background task.' }

      unless id_index
        @logger.fatal('Unique Identifier doesn\'t exist, please choose a column as the Unique Identifier.')
        return
      end

      @file = file
      @id_index = id_index.to_i
      @mappings = mappings
      @project = Project.find(project_id)

      # Hash#find converts a hash into an array,
      # e.g. { '0' => { 'type' => 'node' } } to # ['0', { 'type' => 'node' }].
      @node_index =
        if node_mapping = @mappings.find { |index, field| field['type'] == 'node' }
          node_mapping.first.to_i
        end

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
      @issue_mappings = @mappings.select { |index, mapping| mapping['type'] == 'issue' }
      @evidence_mappings = @mappings.select { |index, mapping| mapping['type'] == 'evidence' }

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

        field_name = @project.report_template_properties ? mapping['field'] : row.headers[index.to_i]
        field_value = row[index.to_i]
        "#[#{field_name}]#\n#{field_value}"
      end.compact.join("\n\n")
    end
  end
end
