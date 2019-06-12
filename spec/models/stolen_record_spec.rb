require "rails_helper"

RSpec.describe StolenRecord, type: :model do
  it "marks current true by default" do
    stolen_record = StolenRecord.new
    expect(stolen_record.current).to be_truthy
  end

  describe "find_or_create_recovery_link_token" do
    let(:stolen_record) { StolenRecord.new }
    it "returns an existing recovery_link_token" do
      stolen_record.recovery_link_token = "blah"
      expect(stolen_record).to_not receive(:save)
      expect(stolen_record.find_or_create_recovery_link_token).to eq "blah"
    end

    it "creates a recovery_link_token and saves" do
      stolen_record = StolenRecord.new
      expect(stolen_record).to receive(:save)
      result = stolen_record.find_or_create_recovery_link_token
      expect(result).to eq stolen_record.recovery_link_token
    end
  end

  describe "scopes" do
    it "default scopes to current" do
      expect(StolenRecord.all.to_sql).to eq(StolenRecord.unscoped.where(current: true).to_sql)
    end
    it "scopes approveds" do
      expect(StolenRecord.approveds.to_sql).to eq(StolenRecord.unscoped.where(current: true).where(approved: true).to_sql)
    end
    it "scopes approveds_with_reports" do
      expect(StolenRecord.approveds_with_reports.to_sql).to eq(StolenRecord.unscoped.where(current: true).where(approved: true)
                                                              .where("police_report_number IS NOT NULL").where("police_report_department IS NOT NULL").to_sql)
    end

    it "scopes not_tsved" do
      expect(StolenRecord.not_tsved.to_sql).to eq(StolenRecord.unscoped.where(current: true).where("tsved_at IS NULL").to_sql)
    end
    it "scopes recovered" do
      expect(StolenRecord.recovered.to_sql).to eq(StolenRecord.unscoped.where(current: false).order("date_recovered desc").to_sql)
    end
    it "scopes displayable" do
      expect(StolenRecord.displayable.to_sql).to eq(StolenRecord.unscoped.where(current: false, can_share_recovery: true).order("date_recovered desc").to_sql)
    end
    it "scopes recovery_unposted" do
      expect(StolenRecord.recovery_unposted.to_sql).to eq(StolenRecord.unscoped.where(current: false, recovery_posted: false).to_sql)
    end
    it "scopes tsv_today" do
      stolen1 = FactoryBot.create(:stolen_record, current: true, tsved_at: Time.now)
      stolen2 = FactoryBot.create(:stolen_record, current: true, tsved_at: nil)

      expect(StolenRecord.tsv_today.pluck(:id)).to eq([stolen1.id, stolen2.id])
    end
  end

  it "only allows one current stolen record per bike"

  describe "address" do
    let(:country) { Country.create(name: "Neverland", iso: "NEVVVV") }
    let(:state) { State.create(country_id: country.id, name: "BullShit", abbreviation: "XXX") }
    it "creates an address" do
      stolen_record = StolenRecord.new(street: "2200 N Milwaukee Ave",
                                       city: "Chicago",
                                       state_id: state.id,
                                       zipcode: "60647",
                                       country_id: country.id)
      expect(stolen_record.address).to eq("Chicago, XXX, 60647, NEVVVV")
      expect(stolen_record.address(override_show_address: true)).to eq("2200 N Milwaukee Ave, Chicago, XXX, 60647, NEVVVV")
      stolen_record.show_address = true
      expect(stolen_record.address).to eq("2200 N Milwaukee Ave, Chicago, XXX, 60647, NEVVVV")
    end
    it "is ok with missing information" do
      stolen_record = StolenRecord.new(street: "2200 N Milwaukee Ave",
                                       zipcode: "60647",
                                       country_id: country.id)
      expect(stolen_record.address).to eq("60647, NEVVVV")
      stolen_record.show_address = true
      expect(stolen_record.address).to eq("2200 N Milwaukee Ave, 60647, NEVVVV")
    end
    it "returns nil if there is no country" do
      stolen_record = StolenRecord.new(street: "302666 Richmond Blvd")
      expect(stolen_record.address).to be_nil
    end
  end

  describe "scopes" do
    it "only includes current records" do
      expect(StolenRecord.all.to_sql).to eq(StolenRecord.unscoped.where(current: true).to_sql)
    end

    it "only includes non-current in recovered" do
      expect(StolenRecord.recovered.to_sql).to eq(StolenRecord.unscoped.where(current: false).order("date_recovered desc").to_sql)
    end

    it "only includes sharable unapproved in recovery_waiting_share_approval" do
      expect(StolenRecord.recovery_unposted.to_sql).to eq(StolenRecord.unscoped.where(current: false, recovery_posted: false).to_sql)
    end
  end

  describe "tsv_row" do
    it "returns the tsv row" do
      stolen_record = FactoryBot.create(:stolen_record)
      stolen_record.bike.update_attribute :description, "I like tabs because i'm an \\tass\T right\N"
      row = stolen_record.tsv_row
      expect(row.split("\t").count).to eq(10)
      expect(row.split("\n").count).to eq(1)
    end

    it "doesn't show the serial for recovered bikes" do
      stolen_record = FactoryBot.create(:stolen_record)
      stolen_record.bike.update_attributes(serial_number: "SERIAL_SERIAL", recovered: true)
      row = stolen_record.tsv_row
      expect(row).not_to match(/serial_serial/i)
    end
  end

  describe "recovery display status" do
    it "is not elibible" do
      expect(StolenRecord.new.recovery_display_status).to eq "not_eligible"
    end
    context "stolen record is recovered, unable to share" do
      let(:stolen_record) { FactoryBot.create(:stolen_record_recovered, can_share_recovery: false) }
      it "is not displayed" do
        stolen_record.reload
        expect(stolen_record.recovery_display_status).to eq "not_eligible"
      end
    end
    context "stolen record is recovered, able to share" do
      let!(:public_image) { FactoryBot.create(:public_image, imageable: bike) }
      let(:stolen_record) { FactoryBot.create(:stolen_record_recovered, can_share_recovery: true) }
      let(:bike) { stolen_record.bike }
      it "is waiting on decision when user marks that we can share" do
        bike.reload.update_attributes(updated_at: Time.now)
        stolen_record.reload.update_attributes(updated_at: Time.now)
        expect(stolen_record.bike.thumb_path).to be_present
        expect(stolen_record.can_share_recovery).to be_truthy
        expect(stolen_record.recovery_display_status).to eq "waiting_on_decision"
      end
    end
    context "stolen record is recovered, sharable but no photo" do
      let(:stolen_record) { FactoryBot.create(:stolen_record_recovered, can_share_recovery: true) }
      it "is not displayed" do
        stolen_record.reload
        expect(stolen_record.recovery_display_status).to eq "displayable_no_photo"
      end
    end
    context "stolen_record is displayed" do
      let!(:stolen_record) { FactoryBot.create(:stolen_record_recovered, can_share_recovery: true, recovery_display: recovery_display) }
      let(:recovery_display) { stolen_record.recovery_display }
      it "is displayed" do
        stolen_record.reload
        expect(stolen_record.recovery_display_status).to eq "displayed"
      end
    end
    context "stolen_record is not_displayed" do
      let(:stolen_record) { FactoryBot.create(:stolen_record_recovered, recovery_display_status: "not_displayed", can_share_recovery: true) }
      it "is not_displayed" do
        stolen_record.reload.update_attributes(updated_at: Time.now)
        expect(stolen_record.recovery_display_status).to eq "not_displayed"
      end
    end
  end

  describe "set_phone" do
    it "it should set_phone" do
      stolen_record = FactoryBot.create(:stolen_record)
      stolen_record.phone = "000/000/0000"
      stolen_record.secondary_phone = "000/000/0000"
      stolen_record.set_phone
      expect(stolen_record.phone).to eq("0000000000")
      expect(stolen_record.secondary_phone).to eq("0000000000")
    end
  end

  describe "phone_display" do # from phoneifyerable
    it "has phone_display" do
      stolen_record = StolenRecord.new(phone: "272 222-22222")
      expect(stolen_record.phone_display).to eq "272.222.22222"
    end
  end

  describe "titleize_city" do
    it "it should titleize_city" do
      stolen_record = FactoryBot.create(:stolen_record)
      stolen_record.city = "INDIANAPOLIS, IN USA"
      stolen_record.titleize_city
      expect(stolen_record.city).to eq("Indianapolis")
    end

    it "it shouldn't remove other things" do
      stolen_record = FactoryBot.create(:stolen_record)
      stolen_record.city = "Georgian la"
      stolen_record.titleize_city
      expect(stolen_record.city).to eq("Georgian La")
    end
  end

  describe "set_calculated_attributes" do
    let(:stolen_record) { FactoryBot.create(:stolen_record) }
    it "has before_save_callback_method defined as before_save callback" do
      expect(stolen_record._save_callbacks.select { |cb| cb.kind.eql?(:before) }.map(&:raw_filter).include?(:set_calculated_attributes)).to eq(true)
    end
  end

  describe "fix_date" do
    it "it should set the year to something not stupid" do
      stolen_record = StolenRecord.new
      stupid_year = Date.strptime("07-22-0014", "%m-%d-%Y")
      stolen_record.date_stolen = stupid_year
      stolen_record.fix_date
      expect(stolen_record.date_stolen.year).to eq(2014)
    end
    it "it should set the year to not last century" do
      stolen_record = StolenRecord.new
      wrong_century = Date.strptime("07-22-1913", "%m-%d-%Y")
      stolen_record.date_stolen = wrong_century
      stolen_record.fix_date
      expect(stolen_record.date_stolen.year).to eq(2013)
    end
    it "it should set the year to the past year if the date hasn't happened yet" do
      stolen_record = FactoryBot.create(:stolen_record)
      next_year = (Time.now + 2.months)
      stolen_record.date_stolen = next_year
      stolen_record.fix_date
      expect(stolen_record.date_stolen.year).to eq(Time.now.year - 1)
    end
  end

  describe "update_tsved_at" do
    it "does not reset on save" do
      t = Time.now - 1.minute
      stolen_record = FactoryBot.create(:stolen_record, tsved_at: t)
      stolen_record.update_attributes(theft_description: "Something new description wise")
      stolen_record.reload
      expect(stolen_record.tsved_at.to_i).to eq(t.to_i)
    end
    it "resets from an update to police report" do
      t = Time.now - 1.minute
      stolen_record = FactoryBot.create(:stolen_record, tsved_at: t)
      stolen_record.update_attributes(police_report_number: "89dasf89dasf")
      stolen_record.reload
      expect(stolen_record.tsved_at).to be_nil
    end
    it "resets from an update to police report department" do
      t = Time.now - 1.minute
      stolen_record = FactoryBot.create(:stolen_record, tsved_at: t)
      stolen_record.update_attributes(police_report_department: "CPD")
      stolen_record.reload
      expect(stolen_record.tsved_at).to be_nil
    end
  end

  describe "calculated_recovery_display_status" do
    context "recovery is not eligible for display" do
      let(:stolen_record) { FactoryBot.create(:stolen_record_recovered, can_share_recovery: false) }
      it "returns not_eligible" do
        expect(stolen_record.calculated_recovery_display_status).to eq "not_eligible"
      end
    end
    context "recovery is eligible for display but has no photo" do
      let(:stolen_record) { FactoryBot.create(:stolen_record_recovered, can_share_recovery: true) }
      it "returns displayable_no_photo" do
        expect(stolen_record.calculated_recovery_display_status).to eq "displayable_no_photo"
      end
    end
    context "recovery is eligible for display" do
      let!(:public_image) { FactoryBot.create(:public_image, imageable: bike) }
      let(:stolen_record) { FactoryBot.create(:stolen_record_recovered, can_share_recovery: true) }
      let(:bike) { stolen_record.bike }
      it "returns waiting_on_decision" do
        bike.reload
        bike.update_attributes(updated_at: Time.now)
        expect(stolen_record.calculated_recovery_display_status).to eq "waiting_on_decision"
      end
    end
    context "recovery is displayed" do
      let!(:stolen_record) { FactoryBot.create(:stolen_record_recovered, can_share_recovery: true, recovery_display: recovery_display) }
      let(:recovery_display) { stolen_record.recovery_display }
      it "returns displayed" do
        expect(stolen_record.calculated_recovery_display_status).to eq "displayed"
      end
    end
    context "recovery has been marked as not eligible for display" do
      let(:stolen_record) { FactoryBot.create(:stolen_record_recovered, can_share_recovery: true, recovery_display_status: "not_displayed") }
      it "returns not_displayed" do
        expect(stolen_record.calculated_recovery_display_status).to eq "not_displayed"
      end
    end
  end

  describe "add_recovery_information" do
    let(:bike) { FactoryBot.create(:stolen_bike) }
    let(:stolen_record) { bike.current_stolen_record }
    let(:user_id) { nil }
    let(:recovery_info) do
      {
        request_type: "bike_recovery",
        user_id: 69,
        request_bike_id: bike.id,
        recovered_description: "Some reason",
        index_helped_recovery: "true",
        can_share_recovery: "false",
        recovering_user_id: user_id,
      }
    end
    before do
      expect(bike.stolen).to be_truthy
      stolen_record.add_recovery_information(recovery_request.as_json)
      bike.reload
      stolen_record.reload

      expect(bike.stolen).to be_falsey
      expect(stolen_record.recovered?).to be_truthy
      expect(stolen_record.current).to be_falsey
      expect(bike.current_stolen_record).not_to be_present
      expect(stolen_record.index_helped_recovery).to be_truthy
      expect(stolen_record.can_share_recovery).to be_falsey
      expect(stolen_record.recovering_user_id).to eq user_id
      stolen_record.reload
    end
    context "no date_recovered, no user" do
      let(:recovery_request) { recovery_info.except(:can_share_recovery) }
      it "updates recovered bike" do
        expect(stolen_record.date_recovered).to be_within(1.second).of Time.now
        expect(stolen_record.recovering_user).to be_blank
        expect(stolen_record.recovering_user_owner?).to be_falsey
      end
    end
    context "owner is bike owner" do
      let(:recovery_request) { recovery_info }
      let(:ownership) { FactoryBot.create(:ownership_claimed, bike: bike) }
      let(:user_id) { ownership.user_id }
      it "updates recovered bike and assigns recovering_user" do
        expect(stolen_record.recovering_user).to eq ownership.user
        expect(stolen_record.date_recovered).to be_within(1.second).of Time.now
        expect(stolen_record.recovering_user_owner?).to be_truthy
        expect(stolen_record.pre_recovering_user?).to be_falsey
      end
    end
    context "date_recovered" do
      let(:user_id) { FactoryBot.create(:user).id }
      let(:time_str) { "2017-01-31T23:57:56" }
      let(:target_timestamp) { 1485907076 }
      let(:recovery_request) { recovery_info.merge(date_recovered: time_str, timezone: "Atlantic/Reykjavik") }
      it "updates recovered bike and assigns date" do
        expect(stolen_record.date_recovered.to_i).to be_within(1).of target_timestamp
        expect(stolen_record.recovering_user_owner?).to be_falsey
        expect(stolen_record.pre_recovering_user?).to be_truthy
      end
    end
  end
end
