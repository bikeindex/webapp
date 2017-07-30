require 'spec_helper'

describe EmailUpdatedTermsWorker do
  it { is_expected.to be_processed_in :afterwards }
  let(:user) { FactoryGirl.create(:organization_member) }
  let(:subject) { EmailUpdatedTermsWorker.new }
  before do
    subject.redis.expire(subject.enqueued_emails_key, 0)
    ActionMailer::Base.deliveries = []
  end

  context 'user id enqueued' do
    it 'sends the updated email' do
      subject.redis.lpush(subject.enqueued_emails_key, user.id)

      subject.perform
      expect(ActionMailer::Base.deliveries.empty?).to be_falsey
      expect(subject.redis.llen(subject.enqueued_emails_key)).to eq 0
    end
  end

  context 'user id not enqueued' do
    it 'does not send the updated email' do
      # Ensure we have an empty list
      subject.redis.lpush(subject.enqueued_emails_key, 1)
      subject.redis.lpop(subject.enqueued_emails_key)

      subject.perform
      expect(ActionMailer::Base.deliveries.empty?).to be_truthy
    end
  end

  context 'message fails to send' do
    it 'pushes the email key back on the updated email' do
      subject.redis.lpush(subject.enqueued_emails_key, 42)

      expect { subject.perform }.to raise_error(ActiveRecord::RecordNotFound)
      expect(ActionMailer::Base.deliveries.empty?).to be_truthy
      expect(subject.redis.llen(subject.enqueued_emails_key)).to eq 1
      expect(subject.redis.lpop(subject.enqueued_emails_key).to_i).to eq 42
    end
  end
end
