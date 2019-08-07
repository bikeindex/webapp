require "rails_helper"

RSpec.describe EmailOwnershipInvitationWorker, type: :job do
  it "sends an email" do
    ownership = FactoryBot.create(:ownership)
    ActionMailer::Base.deliveries = []
    EmailOwnershipInvitationWorker.new.perform(ownership.id)
    expect(ActionMailer::Base.deliveries).not_to be_empty
  end

  context "ownership does not exist" do
    it "does not send an email" do
      ActionMailer::Base.deliveries = []
      EmailOwnershipInvitationWorker.new.perform(129291912)
      expect(ActionMailer::Base.deliveries).to be_empty
    end
  end
  context "ownership is for an example bike" do
    let(:bike) { FactoryBot.create(:bike, example: true) }
    let(:ownership) { FactoryBot.create(:ownership, bike: bike) }
    it "does not send, updates ownership to be send_email false" do
      ownership.reload
      expect(ownership.send_email).to be_truthy
      ActionMailer::Base.deliveries = []
      EmailOwnershipInvitationWorker.new.perform(ownership.id)
      expect(ActionMailer::Base.deliveries).to be_empty
      ownership.reload
      expect(ownership.send_email).to be_falsey
    end
  end
end
