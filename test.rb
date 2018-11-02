require 'MCP4821'
mcp4821 = MCP4821.new PiPiper::Spi::CHIP_SELECT_0
mcp4821.set_latch_pin xx
mcp4821.set_hw_shdn_pin xx
mcp4821.set_out_gain 'x1'
mcp4821.set_without_latch

print 'write without latch'
(0..4095).each do |dac|
      mcp4821.write dac
      end
sleep 5

print 'shut down'
mcp4821.shdn
sleep 5

print 'with latch'
mcp4821.set_with_latch
mcp4821.write 2047
sleep 5
print 'latch!'
mcp4821.latch
sleep 5
print 'shut down'
mcp4821.shdn
