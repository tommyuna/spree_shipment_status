module Spree
  class NotifyMailer < BaseMailer
    def notify_email(subject, text)
      @content = text
      subject = subject
      mail(to: 'dev@gosnapshop.com', from: from_address, subject: subject)
    end
  end
end
