require "spec_helper"

describe Timber::Events::Custom, :rails_23 => true do
  describe ".to_hash" do
    it "should coerce type into an atom" do
      custom_event = described_class.new(:type => "my type", :message => "hello", :data => {:key => "value"})
      hash = custom_event.to_hash()
      expect(hash.keys.first).to eq(:"my type")
    end

    it "should coerce a Time into a float representing fractional milliseconds" do
      timer = Timber::Timber.start
      custom_event = described_class.new(:type => :my_event, :message => "hello", :data => {:time_ms => timer})
      data = custom_event.data
      expect(data[:time_ms]).to be_kind_of(Float)
      expect(data[:time_ms]).to be > 0
    end
  end
end