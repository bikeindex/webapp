require "rails_helper"

RSpec.describe EmailConfirmationWorker, type: :job do
  it "sends a welcome email" do
    user = FactoryBot.create(:user)
    ActionMailer::Base.deliveries = []
    EmailConfirmationWorker.new.perform(user.id)
    expect(ActionMailer::Base.deliveries.empty?).to be_falsey
  end

  it 'deletes user if email is invalid' do
    user = FactoryGirl.create(:user)
    user.update(email: 'notaemail@fakeonotreal.blorgh')
    EmailConfirmationWorker.new.perform(user.id)
    expect(User.count).to be_zero
  end
end
