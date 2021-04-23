# frozen_string_literal: true

module MoneyFormattable
  extend ActiveSupport::Concern

  module ClassMethods
    include MoneyRails::ActionViewExtension

    def default_currency
      "USD"
    end

    def money_formatted(amnt, currency = nil)
      Money.new(amnt || 0, currency || default_currency).format
    end

    def money_formatted_without_cents(amnt, currency = nil)
      money_without_cents_and_with_symbol Money.new(amnt || 0, currency || default_currency)
    end

    def convert_to_cents(amnt)
      amnt.to_f * 100
    end
  end
end
