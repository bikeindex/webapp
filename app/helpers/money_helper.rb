module MoneyHelper
  include MoneyRails::ActionViewExtension

  Money.default_bank.add_rate(:USD, :EUR, 0.88)

  def default_currency
    t("number.currency.alphabetic_code")
  end

  def money_usd(dollars, exchange_to: default_currency)
    Money.new(dollars * 100, :USD).exchange_to(exchange_to)
  end

  def as_currency(dollars_usd, exchange_to: default_currency)
    money_without_cents_and_with_symbol(money_usd(dollars_usd, exchange_to: exchange_to))
  end
end
