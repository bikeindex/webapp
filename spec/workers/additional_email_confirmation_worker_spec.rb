require 'spec_helper'

describe AdditionalEmailConfirmationWorker do
  it { is_expected.to be_processed_in :notify }

  it 'sends a confirm your additional email, email' do
    # user = FactoryGirl.create(:confirmed_user)
    # user_email = FactoryGirl.create(:user_email, user: user)
    # AdditionalEmailConfirmationWorker.new.perform(user_email.id)
    # expect(ActionMailer::Base.deliveries.empty?).to be_falsey
  end
end
