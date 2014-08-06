require 'spec_helper'

describe "OhmyzipScraper" do
  let(:scraper) { Spree::WarpexScraper.new }


  it "should return nokogiri doc when call get_html_doc method" do
    doc = scraper.get_html_doc scraper.addresses['tracking_page']
    expect(doc).to be_a(Nokogiri::HTML::Document)
  end

  it "should raise an error when there is no page at the address" do
    expect {
      scraper.get_html_doc("http://www.nonexsting.page/")
    }.to raise_error
  end

  it "has to correctly get an delivery status from tracking page" do
    dbl_scraper = class_double('WarpexScraper')
    allow(dbl_scraper).to receive(:get_tracking_page) {
      file = File.open("#{Rails.root}/spec/resource/tracking_page.html", "r")
      Nokogiri::HTML.parse(file.read)
    }
    doc = dbl_scraper.get_tracking_page
    status = scraper.get_single_text(doc, scraper.selectors['status'])
    expect(scraper.status.has_value? status.attribute('src').value).to eq(true)
  end
end
