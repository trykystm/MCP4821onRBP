require 'mcp4821_RBP'
RSpec.describe MCP4821 do
  describe '#write(dac)' do
    subject do
      mcp4821 = MCP4821.new
      mcp4821.write(dac)
    end
    context 'when dac is 1845' do
      let(:dac){1845}
      it {is_expected.to eq }
    end
  end
end
