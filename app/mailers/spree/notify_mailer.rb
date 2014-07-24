module Spree
  class NotifyMailer < BaseMailer
    def notify_email(subject, text)
      @content = text
      subject = subject
      mail(to: 'hello@luuv.it', from: from_address, subject: subject)
    end
  end
end
