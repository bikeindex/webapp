require "rails_helper"

RSpec.describe UserAlert, type: :model do
  describe "update_phone_waiting_confirmation" do
    let(:user) { FactoryBot.create(:user) }
    let(:user_phone) { FactoryBot.create(:user_phone, user: user) }
    it "creates only once" do
      user_alert = UserAlert.update_phone_waiting_confirmation(user, user_phone)
      expect(user_alert).to be_valid
      expect(user_alert.active?).to be_truthy
      expect(user_alert.kind).to eq "phone_waiting_confirmation"
      expect(user_alert.active?).to be_truthy
      expect(user_alert.inactive?).to be_falsey
      # It doesn't create a second time
      expect {
        UserAlert.update_phone_waiting_confirmation(user, user_phone)
      }.to_not change(UserAlert, :count)
      expect(user.user_alerts.pluck(:id)).to eq([user_alert.id])
      # Dismissing
      user_alert.dismiss!
      expect(user_alert.dismissed_at).to be_within(1).of Time.current
      expect(user_alert.dismissed?).to be_truthy
      expect(user_alert.active?).to be_falsey
      expect(user_alert.inactive?).to be_truthy
      expect(user_alert.resolved?).to be_falsey
    end
  end
end
