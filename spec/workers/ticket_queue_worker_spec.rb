require "rails_helper"

RSpec.describe TicketQueueWorker, type: :job do
  let(:instance) { described_class.new }

  describe "perform" do
    let(:location) { FactoryBot.create(:location, :with_virtual_line_on) }
    let(:organization) { location.organization }
    it "marks the next tickets as in line" do
      stub_const("TicketQueueWorker::DEFAULT_TICKETS_IN_LINE_COUNT", 5)
      Ticket.create_tickets(10, initial_number: 101, organization: organization) # Tests that it pulls the default location
      organization.reload
      expect(organization.tickets.count).to eq 10
      expect(organization.tickets.unused.count).to eq 10
      ticket1 = organization.tickets.number_ordered.first
      ticket2 = organization.tickets.friendly_find(102)
      expect(ticket1.number).to eq 101
      instance.perform(ticket2.id)
      ticket1.reload
      expect(ticket1.status).to eq "unused"
      ticket2.reload
      expect(ticket2.status).to eq "in_line"
      expect(organization.tickets.unused.count).to eq 5
      expect(organization.tickets.in_line.count).to eq 5
      ticket3 = organization.tickets.friendly_find(103)
      instance.perform(ticket3.id)
      ticket2.reload
      expect(ticket2.in_line?).to be_truthy
      expect(organization.tickets.unused.count).to eq 4
      expect(organization.tickets.in_line.count).to eq 6
      # If passed resolve_earlier_tickets, it marks them resolved
      instance.perform(ticket3.id, true)
      ticket1.reload
      expect(ticket1.status).to eq "unused"
      ticket2.reload
      expect(ticket2.status).to eq "resolved"
      ticket3.reload
      expect(ticket3.status).to eq "in_line"
      expect(organization.tickets.unused.count).to eq 4
      expect(organization.tickets.in_line.count).to eq 5
      expect(organization.tickets.resolved.count).to eq 1
    end
  end
end
