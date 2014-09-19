Spree::ShipmentMailer.class_eval do
  def shipped_email(shipment, resend = false)
    @shipment = shipment.respond_to?(:id) ? shipment : Spree::Shipment.find(shipment)
    subject = (resend ? "[#{Spree.t(:resend).upcase}] " : '')
    subject += "#{Spree::Config[:site_name]} 배송안내드립니다. ##{@shipment.order.number}"
    mail(to: @shipment.order.email, from: from_address, subject: subject)
  end
end
