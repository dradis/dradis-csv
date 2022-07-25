require 'rails_helper'

# To run, execute from Dradis main app folder:
#   bin/rspec [dradis-plugins path]/spec/features/upload_spec.rb

describe 'upload feature', js: true do
  before do
    login_to_project_as_user
    visit project_upload_path(@project)
  end

  context 'uploading a CSV file' do
    let(:file_path) { File.expand_path('../fixtures/files/simple.csv', __dir__) }
    before do
      @headers = CSV.open(file_path, &:readline)

      select 'Dradis::Plugins::CSV', from: 'uploader'

      within('.custom-file') do
        page.find('#file', visible: false).attach_file(file_path)
      end

      find('body.upload.new', wait: 30)
    end

    it 'redirects to the mapping page' do
      expect(current_path).to eq(csv.new_project_upload_path(@project))
    end

    it 'lists the fields in the table' do
      within('tbody') do
        @headers.each do |header|
          expect(page).to have_selector('td', text: header)
        end
      end
    end

    context 'mapping CSV columns' do
      context 'when identifier not selected' do
        it 'shows a validation message on the page' do
          within all('tbody tr')[3] do
            select 'Evidence Field'
          end

          click_button 'Import CSV'
          expect(page).to have_text('An Issue ID must be selected.')
        end
      end

      context 'when there are evidence type but no node type selected' do
        it 'shows a validation message on the page' do
          within all('tbody tr')[2] do
            select 'Issue ID'
          end

          within all('tbody tr')[3] do
            select 'Evidence Field'
          end

          click_button 'Import CSV'
          expect(page).to have_text('A Node Label Type must be selected to import evidence records.')
        end
      end

      context 'when project does not have RTP' do
        it 'imports all columns as fields' do
          select 'Issue ID', from: 'mappings[field_attributes][0][type]'
          select 'Node', from: 'mappings[field_attributes][3][type]'
          select 'Evidence Field', from: 'mappings[field_attributes][4][type]'
          select 'Evidence Field', from: 'mappings[field_attributes][5][type]'

          perform_enqueued_jobs do
            click_button 'Import CSV'

            find('#console .log', wait: 30, match: :first)

            expect(page).to have_text('Worker process completed.')

            issue = Issue.last
            expect(issue.fields).to eq({ 'Description' => 'Test CSV', 'Title' => 'SQL Injection', 'VulnerabilityCategory' =>'High', 'plugin' => 'csv', 'plugin_id' => '1' })

            node = issue.affected.first
            expect(node.label).to eq('10.0.0.1')

            evidence = node.evidence.first
            expect(evidence.fields).to eq({ 'Label' => '10.0.0.1', 'Title' => 'SQL Injection', 'Location' => '10.0.0.1', 'Port' => '443' })
          end
        end
      end

      context 'when project have RTP' do
        before do
          rtp = create(:report_template_properties, evidence_fields: evidence_fields, issue_fields: issue_fields)
          @project.update(report_template_properties: rtp)

          page.refresh
        end

        context 'without fields' do
          let (:evidence_fields) { [] }
          let (:issue_fields) { [] }

          it 'creates records with fields from the headers' do
            select 'Issue ID', from: 'mappings[field_attributes][0][type]'
            select 'Node', from: 'mappings[field_attributes][3][type]'
            select 'Evidence Field', from: 'mappings[field_attributes][4][type]'
            select 'Evidence Field', from: 'mappings[field_attributes][5][type]'

            perform_enqueued_jobs do
              click_button 'Import CSV'

              find('#console .log', wait: 30, match: :first)

              expect(page).to have_text('Worker process completed.')

              issue = Issue.last
              expect(issue.fields).to eq({ 'Description' => 'Test CSV', 'Title' => 'SQL Injection', 'Vulnerability Category' =>'High', 'plugin' => 'csv', 'plugin_id' => '1' })

              node = issue.affected.first
              expect(node.label).to eq('10.0.0.1')

              evidence = node.evidence.first
              expect(evidence.fields).to eq({ 'Label' => '10.0.0.1', 'Location' => '10.0.0.1', 'Title' => 'SQL Injection', 'Port' => '443' })
            end
          end
        end

        context 'with fields' do
          let (:evidence_fields) {
            [
              { name: 'Location', type: :string, default: true },
              { name: 'Port', type: :string, default: true}
            ]
          }

          let (:issue_fields) {
            [
              { name: 'Title', type: :string, default: true },
              { name: 'Description', type: :string, default: true},
              { name: 'Severity', type: :string, default: true}
            ]
          }

          it 'shows the available fields for the selected type' do
            select 'Issue Field', from: 'mappings[field_attributes][1][type]'

            issue_fields.each do |field|
              expect(page).to have_selector('option', text: field[:name])
            end

            select 'Evidence Field', from: 'mappings[field_attributes][4][type]'

            evidence_fields.each do |field|
              expect(page).to have_selector('option', text: field[:name])
            end
          end

          it 'can select which columns to import' do
            select 'Issue ID', from: 'mappings[field_attributes][0][type]'

            select 'Issue Field', from: 'mappings[field_attributes][1][type]'
            select 'Title', from: 'mappings[field_attributes][1][field]'

            select 'Issue Field', from: 'mappings[field_attributes][2][type]'
            select 'Description', from: 'mappings[field_attributes][2][field]'

            select 'Node', from: 'mappings[field_attributes][3][type]'

            select 'Evidence Field', from: 'mappings[field_attributes][4][type]'
            select 'Location', from: 'mappings[field_attributes][4][field]'

            select 'Evidence Field', from: 'mappings[field_attributes][5][type]'
            select 'Port', from: 'mappings[field_attributes][5][field]'

            select 'Issue Field', from: 'mappings[field_attributes][6][type]'
            select 'Severity', from: 'mappings[field_attributes][6][field]'

            perform_enqueued_jobs do
              click_button 'Import CSV'

              find('#console .log', wait: 30, match: :first)

              expect(page).to have_text('Worker process completed.')

              issue = Issue.last
              expect(issue.fields).to eq({ 'Description' => 'Test CSV', 'Title' => 'SQL Injection', 'Severity' => 'High', 'plugin' => 'csv', 'plugin_id' => '1' })

              node = issue.affected.first
              expect(node.label).to eq('10.0.0.1')

              evidence = node.evidence.first
              expect(evidence.fields).to eq({ 'Label' => '10.0.0.1', 'Location' => '10.0.0.1', 'Title' => 'SQL Injection', 'Port' => '443' })
            end
          end
        end

        context 'when no evidence fields' do
          let (:evidence_fields) { [] }
          let (:issue_fields) { [] }

          it 'still creates evidence record' do
            within all('tbody tr')[1] do
              select 'Node'
            end

            within all('tbody tr')[2] do
              select 'Issue ID'
            end

            within all('tbody tr')[5] do
              select 'Issue Field'
            end

            perform_enqueued_jobs do
              click_button 'Import CSV'

              find('#console .log', wait: 30, match: :first)

              expect(page).to have_text('Worker process completed.')

              issue = Issue.last
              expect(issue.fields).to include({ 'Title' => 'SQL Injection', 'plugin' => 'csv', 'plugin_id' => '1' })

              node = issue.affected.first
              expect(node.label).to eq('10.0.0.1')

              evidence = node.evidence.first
              expect(evidence.content).to eq('')
            end
          end
        end
      end
    end
  end
end
