require 'pi_piper'
#include 'PiPiper::Spi'

class MCP4821 < PiPiper::Spi
  
  CE0 = CHIP_SELECT_0
  CE1 = CHIP_SELECT_1
  
  def initialize(chip = CE0)
    PiPiper::Spi.begin(chip) do |spi|
      @spi = spi
      @gain = "x1"
    end
  end
  
  def write(dac)
    command = 0b0011000000000000 + dac
    first = command >> 8
    second = command & 0b0000000011111111
    @spi.write first, second
  end
  
  def latch
  end
  
  def shdn
    @spi.write 0b0001000, 0b000000000
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

  if __FILE__ == $0
    mcp4821 = self.new CE1
    (0..4095).each do |dac|
      mcp4821.write dac
    end
    sleep 5
    mcp4821.shdn
  end
  
end

