require 'rails_helper'

RSpec.describe Dradis::Plugins::CSV::MappingImportJob do
  let(:file) { File.expand_path('../../../.../../../fixtures/files/simple.csv', __dir__) }

  let(:perform_job) do
    described_class.new.perform(
      default_user_id: create(:user).id,
      file: file,
      mappings: {},
      project_id: create(:project).id,
      uid: 1
    )
  end

  describe '#perform' do
    it 'calls Importer#import_csv' do
      dbl = double('Importer')
      allow(Dradis::Plugins::CSV::Importer).to receive(:new).and_return(dbl)
      expect(dbl).to receive(:import_csv).and_return(true)

      perform_job
    end

    it 'writes a known final line in the log' do
      perform_job
      expect(Log.last.text).to eq 'Worker process completed.'
    end
  end
end
