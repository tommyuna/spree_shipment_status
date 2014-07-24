require 'spec_helper'

describe "GmailScraper" do
  let(:scraper) { Spree::GmailScraper.new }

  it "should able to login with correct id and password" do
    result = scraper.login(scraper.login_info['userid'],
                           scraper.login_info['password'])
    expect(result).to eq(true)
  end

  it "should detect login fail" do
    result = scraper.login('id', 'pwd')
    expect(result).to eq(false)
  end

  it "should return nokogiri doc when call get_html_doc method" do
    result = scraper.login(scraper.login_info['userid'],
                           scraper.login_info['password'])
    unless result == false
      query = ['FROM', scraper.addresses['amz_shipping_confirm'],
               'SINCE', scraper.get_imap_date(-30)]
      uids = scraper.get_uid_list query
      doc = scraper.get_html_doc uids.first
    end
    expect(doc).to be_a(Nokogiri::HTML::Document)
  end

  it "should raise an error when there is no email in the uid" do
    expect {
      scraper.get_html_doc 0
    }.to raise_error
  end

  context "with amazon order-confirm email" do

    it "get an order number" do
      dbl_scraper = class_double("GmailScraper")
      allow(dbl_scraper).to receive(:get_html_doc) {
        file = File.open("#{Rails.root}/spec/resource/amazon_order_confirm.html", "r")
        Nokogiri::HTML.parse(file.read)
      }

      doc = dbl_scraper.get_html_doc
      order_id = scraper.get_single_text(doc, scraper.selectors['amz_order_confirm'])
      expect(order_id.text).to eq("114-8962271-7517019")
    end
=begin
    it "successfully update shipment status" do
    #currently there is nothing to do with order confirm email
    end
=end
  end
  context "with amazon shipping-confirm email" do
    it "get an order number" do
      dbl_scraper = class_double("GmailScraper")
      allow(dbl_scraper).to receive(:get_html_doc) {
        file = File.open("#{Rails.root}/spec/resource/amazon_shipping_confirm.html", "r")
        Nokogiri::HTML.parse(file.read)
      }
      doc = dbl_scraper.get_html_doc
      order_id = scraper.get_single_text(doc, scraper.selectors['amz_shipping_confirm'])
      expect(order_id.text).to eq("002-8332150-0273825")
    end

#    it "successfully update shipment status" do
#      create_our_order
#      order.shipments.each do |shipment|
#        puts shipment
#        expect(order.shipment.state).to eq('shipped')
#      end
#    end
  end
  context "with package tracker delivery-confirm email" do
    it "get an order number" do
      dbl_scraper = class_double("GmailScraper")
      allow(dbl_scraper).to receive(:get_html_doc) {
        file = File.open("#{Rails.root}/spec/resource/package_tracker_confirm.html", "r")
        Nokogiri::HTML.parse(file.read)
      }
      doc = dbl_scraper.get_html_doc
      order_id = scraper.get_single_text(doc, scraper.selectors['package_tracker_confirm'])
      expect(order_id.text).to eq("R826816146")
    end

#    it "successfully update shipment status" do
#    end
  end
  def create_our_order(args={})
    params = {}
    @variant = create(:multi_currency_variant)
    params = {variant: @variant}
    @line_item = create(:line_item_in_usd, variant: @variant)
    @order = @line_item.order
    @shipping_method = create(:shipping_method)
    @shipping_method.calculator.preferred_amount = 0.10
    @shipping_method.save
    @shipping_address = create(:shipping_address)
    @shipment = create(:shipment, {number: 1, cost: 10, address: @shipping_address})
    @payment = create(:payment, { amount: 50 } )
    @order.shipments = [@shipment]
    @tax_adjustment = create(:tax_adjustment, { adjustable: @line_item })
    @order.line_items.reload
    @order.update!
  end
end
