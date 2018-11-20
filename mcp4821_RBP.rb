require 'pi_piper'
#include 'PiPiper::Spi'

class MCP4821 < PiPiper::Spi
  
  def initialize(chip = PiPiper::Spi::CHIP_SELECT_0)
    PiPiper::Spi.begin(chip) do |spi|
      @spi = spi
      @gain = :x1
    end
  end
  
  def write(dac, gain = @gain)
    command = 0b0011
    command -= 0b0010 if gain == :x2
    first = command * 0b10000 + (dac & 0b111100000000) / 0b100000000
    second = dac & 0b11111111
    @spi.write first, second
  end
  
  def latch
  end
  
  def shdn
    @spi.write 0, 0
  end
  
  def hw_shdn
  end
  
  def hw_shdn_release
  end
  

  def set_hw_shdn_pin(pin)
    @hw_shdn_pin = pin
  end
  
  def set_latch_pin(pin)
    @latch_pin = pin
  end
  
  def set_out_gain(gain = :x1)
    @gain = gain
  end

  
  if __FILE__ == $0
    mcp4821 = self.new CE1
    (0..4095).each do |dac|
      mcp4821.write dac
    end
    sleep 5
    mcp4821.shdn
  end
  
end

