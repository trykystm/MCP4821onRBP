describe MCP4821 do
  describe '#write(dac)' do
    subject {mcp4821.write(dac)}
    let(:mcp4821){MCP4821.new}
    context 'when dac is 1845' do
      let(:dac){1845}
      it {is_expected.to eq }
    end
  end
end
