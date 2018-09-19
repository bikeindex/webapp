require "spec_helper"

describe OrganizationExportWorker do
  let(:subject) { OrganizationExportWorker }
  let(:instance) { subject.new }
  let(:export) { FactoryGirl.create(:export_organization, progress: "pending") }
  let(:organization) { export.organization }
  let(:black) { FactoryGirl.create(:color, name: "Black") } # Because we use it as a default color
  let(:trek) { FactoryGirl.create(:manufacturer, name: "Trek") }

  # let(:sample_csv_lines) do
  #   [
  #     %w[manufacturer model year color email serial],
  #     ["Trek", "Roscoe 8", "2019", "Green", "test@bikeindex.org", "xyz_test"],
  #     ["Surly", "Midnight Special", "2018", "White", "test2@bikeindex.org", "example"]
  #   ]
  # end
  # let(:csv_lines) { sample_csv_lines }
  # let(:csv_string) { csv_lines.map { |r| r.join(",") }.join("\n") }

  describe "perform" do
    context "bulk import already processed" do
      let(:bulk_import) { FactoryGirl.create(:export, progress: "finished") }
      it "returns true" do
        expect(instance).to_not receive(:process_csv)
        instance.perform(bulk_import.id)
      end
    end
  end

  context "with assigned export" do
    before { instance.export = export }

    describe "bike_to_row" do
      let(:bike) { FactoryGirl.create(:bike, manufacturer: trek, primary_frame_color: black) }
      let(:target_hash) do
        {
          registered_at: bike.created_at.utc,
          manufacturer: "Trek",
          model: "",
          color: "Black",
          serial: bike.serial_number,
          is_stolen: false
        }
      end
      context "default" do
        it "returns the hash we want" do
          expect(instance.bike_to_row(bike)).to eq target_hash.values
        end
      end
    end
  end
end
