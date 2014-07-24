require 'spec_helper'

describe "OhmyzipScraper" do
  let(:scraper) { Spree::OhmyzipScraper.new }

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
      doc = scraper.get_html_doc scraper.addresses['order_list']
    end
    expect(doc).to be_a(Nokogiri::HTML::Document)
  end

  it "should raise an error when there is no page at the address" do
    expect {
      scraper.get_html_doc("http://www.nonexsting.page/")
    }.to raise_error
  end

  context "for one specific order" do
    it "has to correctly get an ohmyzipid and tracking id from order list page" do
      dbl_scraper = class_double('OhmyzipScraper')
      allow(dbl_scraper).to receive(:get_order_list) {
        file = File.open("#{Rails.root}/spec/resource/ohmyzip_order_list_page.html", "r")
        Nokogiri::HTML.parse(file.read)
      }
      doc = dbl_scraper.get_order_list
      scraper.get_multiple_text(doc, scraper.selectors['order_list_row']).each do |selected|
        @shipment_id = scraper.get_single_text(selected, scraper.selectors['order_list_shipment_id'])
        @tracking_id = scraper.get_single_text(selected, scraper.selectors['order_list_tracking_id'])
        break unless @shipment_id == nil
      end
      expect(@shipment_id.text).to eq("1404014651")
      expect(@tracking_id.text).to eq("331809153533")
    end

    it "has to correctly get an store and store order id order detail page" do
      dbl_scraper = class_double('OhmyzipScraper')
      allow(dbl_scraper).to receive(:get_order_detail) {
        file = File.open("#{Rails.root}/spec/resource/ohmyzip_order_detail_page.html", "r")
        Nokogiri::HTML.parse(file.read)
      }
      doc = dbl_scraper.get_order_detail
      store = scraper.get_single_text(doc, scraper.selectors['order_detail_store'])
      store_order_id = scraper.get_single_text(doc, scraper.selectors['order_detail_store_order_id'])

      expect(store.text).to eq("www.amazon.com")
      expect(store_order_id.text).to eq("115-2200176-2397864")
    end
  end
end
