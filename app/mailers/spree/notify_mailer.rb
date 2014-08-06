module Spree
  class NotifyMailer < BaseMailer
    def notify_email(subject, text)
      @content = text
      subject = subject
      mail(to: 'jonghun.yu@gosnapshop', from: from_address, subject: subject)
    end
  end
end
