require 'rails_helper'

RSpec.describe Dradis::Plugins::CSV::Importer do
  let(:file) { File.expand_path('../../../.../../../fixtures/files/simple.csv', __dir__) }
  let(:headers) { CSV.open(file, &:readline) }
  let(:project) { create(:project) }

  let(:instance) do
    described_class.new(
      default_user_id: create(:user).id,
      logger: Log.new(uid: 1),
      plugin: Dradis::Plugins::CSV,
      project_id: project.id
    )
  end

  let(:import_csv) do
    instance.import_csv(file: file, headers: headers, mappings: mappings)
  end

  describe '#import_csv' do
    context 'when project has RTP' do
      let(:mappings) do
        {
          '0' => { 'type' => 'identifier' },
          '1' => { 'type' => 'issue', 'field' => 'MyTitle' },
          '3' => { 'type' => 'node', 'field' => '' },
          '4' => { 'type' => 'evidence', 'field' => 'MyLocation' },
          '5' => { 'type' => 'evidence', 'field' => '' }
        }
      end

      before do
        project.update(report_template_properties: create(:report_template_properties))
      end

      it 'uses the field as Dradis Field' do
        import_csv

        issue = Issue.first
        expect(issue.fields).to eq({ 'MyTitle' => 'SQL Injection', 'plugin' => 'csv', 'plugin_id' => '1' })

        node = issue.affected.first
        expect(node.label).to eq('10.0.0.1')

        evidence = node.evidence.first
        expect(evidence.fields).to eq({ 'Label' => '10.0.0.1', 'Title' => '(No #[Title]# field)', 'MyLocation' => '10.0.0.1' })
      end
    end

    context 'when project does not have RTP' do
      let(:mappings) do
        {
          '0' => { 'type' => 'identifier' },
          '1' => { 'type' => 'issue', 'field' => 'MyTitle' },
          '3' => { 'type' => 'node', 'field' => '' },
          '4' => { 'type' => 'evidence', 'field' => 'MyLocation' },
          '5' => { 'type' => 'evidence', 'field' => '' },
          '6' => { 'type' => 'issue', 'field' => '' }
        }
      end

      it 'uses the column name as Dradis Field' do
        import_csv

        issue = Issue.first
        expect(issue.fields).to eq({ 'Title' => 'SQL Injection', 'VulnerabilityCategory' => 'High', 'plugin' => 'csv', 'plugin_id' => '1' })

        node = issue.affected.first
        expect(node.label).to eq('10.0.0.1')

        evidence = node.evidence.first
        expect(evidence.fields).to eq({ 'Label' => '10.0.0.1', 'Location' => '10.0.0.1', 'Port' => '443', 'Title' => 'SQL Injection' })
      end

      it 'strips out whitespace from column header' do
        import_csv

        issue = Issue.first
        expect(issue.fields.keys).to include('VulnerabilityCategory')
      end
    end

    context 'when mapping does not have a node type' do
      let(:mappings) do
        {
          '0' => { 'type' => 'identifier' },
          '1' => { 'type' => 'issue' },
          '4' => { 'type' => 'evidence' }
        }
      end

      it 'does not create node and evidence' do
        import_csv

        issue = Issue.last
        expect(issue.affected.length).to eq(0)
        expect(issue.evidence.length).to eq(0)
      end
    end

    context 'when no identifier is passed in' do
      let(:mappings) do
        {
          '1' => { 'type' => 'issue' },
          '4' => { 'type' => 'evidence' }
        }
      end

      it 'uses filename and row index as csv_id' do
        import_csv

        issue = Issue.last
        expect(issue.fields).to eq({ 'Title' => 'SQL Injection', 'plugin' => 'csv', 'plugin_id' => 'simple.csv-0' })
      end
    end

    context 'when no evidence fields' do
      let(:mappings) do
        {
          '0' => { 'type' => 'identifier' },
          '1' => { 'type' => 'issue', 'field' => 'MyTitle' },
          '3' => { 'type' => 'node', 'field' => '' }
        }
      end

      it 'still creates evidence record' do
        import_csv

        issue = Issue.first
        expect(issue.fields).to eq({ 'Title' => 'SQL Injection', 'plugin' => 'csv', 'plugin_id' => '1' })

        node = issue.affected.first
        expect(node.label).to eq('10.0.0.1')

        evidence = node.evidence.first
        expect(evidence.content).to eq('')
      end
    end
  end

  describe '#import' do
    context 'when the project has no RTP' do
      it 'does not import anything' do
        expect(instance.import(file: file)).to eq(false)
        expect(Issue.count).to eq(0)
      end
    end

    context 'when the project has RTP but no saved mapping' do
      before do
        project.update(report_template_properties: create(:report_template_properties))
      end

      it 'does not import anything' do
        expect(instance.import(file: file)).to eq(false)
        expect(Issue.count).to eq(0)
      end
    end

    context 'when a saved mapping exists for these headers' do
      let(:rtp) { create(:report_template_properties) }

      before do
        project.update(report_template_properties: rtp)

        issue_mapping = Mapping.create!(
          component: 'csv',
          source: Dradis::Plugins::CSV.mapping_source(headers: headers, entity: :issue),
          destination: rtp.as_mapping_destination
        )
        issue_mapping.mapping_fields.create!(
          source_field: 'Id', destination_field: 'plugin_id', content: '{{ csv[Id] }}'
        )
        issue_mapping.mapping_fields.create!(
          source_field: 'Title', destination_field: 'Title', content: '{{ csv[Title] }}'
        )

        evidence_mapping = Mapping.create!(
          component: 'csv',
          source: Dradis::Plugins::CSV.mapping_source(headers: headers, entity: :evidence),
          destination: rtp.as_mapping_destination
        )
        evidence_mapping.mapping_fields.create!(
          source_field: 'Host', destination_field: 'node_label', content: '{{ csv[Host] }}'
        )
        evidence_mapping.mapping_fields.create!(
          source_field: 'Location', destination_field: 'Location', content: '{{ csv[Location] }}'
        )
      end

      it 'imports using the saved mapping' do
        expect(instance.import(file: file)).to eq(true)

        issue = Issue.last
        expect(issue.fields).to include('Title' => 'SQL Injection', 'plugin_id' => '1')

        node = issue.affected.first
        expect(node.label).to eq('10.0.0.1')

        evidence = node.evidence.first
        expect(evidence.fields).to include('Location' => '10.0.0.1')
      end
    end
  end
end
