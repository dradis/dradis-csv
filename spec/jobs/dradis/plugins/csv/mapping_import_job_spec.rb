require 'rails_helper'

RSpec.describe Dradis::Plugins::CSV::MappingImportJob do
  let(:file) { File.expand_path('../../../.../../../fixtures/files/simple.csv', __dir__) }

  let(:perform_job) do
    described_class.new.perform(
      default_user_id: create(:user).id,
      file: file,
      headers: CSV.open(file, &:readline),
      mappings: {},
      project_id: create(:project).id,
      state: 'draft',
      uid: 1
    )
  end

  describe '#perform' do
    it 'calls Importer#import_rows' do
      dbl = double('Importer')
      allow(Dradis::Plugins::CSV::Importer).to receive(:new).and_return(dbl)
      expect(dbl).to receive(:import_rows).and_return(true)

      perform_job
    end

    it 'writes a known final line in the log' do
      perform_job
      expect(Log.last.text).to eq 'Worker process completed.'
    end
  end
end
