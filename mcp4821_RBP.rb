# frozen_string_literal: true

require 'spi'

# Raspberry Pi 上の MCP4821 (12-bit D/A コンバータ) を制御するクラス
# spi gem を使用して Linux 標準の spidev インターフェースと通信を行います。
class MCP4821
  CE0 = '/dev/spidev0.0'
  CE1 = '/dev/spidev0.1'

  CMD_GAIN_X1 = 0b0011
  CMD_GAIN_X2 = 0b0001

  DEFAULT_SPEED_HZ = 1_000_000

  attr_reader :device_path, :speed_hz, :gain, :latch_pin, :hw_shdn_pin

  def initialize(device = CE0, speed_hz: DEFAULT_SPEED_HZ)
    @device_path = resolve_device(device)
    @speed_hz = speed_hz
    @gain = :x1
    @spi = SPI.new(device: @device_path)
    @spi.speed = @speed_hz
  end

  # DAC 出力値を書き込み（0〜4095）
  def write(dac, gain = @gain)
    command = gain.to_sym == :x2 ? CMD_GAIN_X2 : CMD_GAIN_X1
    first = (command << 4) | ((dac >> 8) & 0x0F)
    second = dac & 0xFF
    transfer(first, second)
  end

  def set_without_latch
  end

  def set_with_latch
  end

  def latch
  end

  # ソフトウェアシャットダウン（SHDNビット = 0）
  def shdn
    transfer(0, 0)
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
    @gain = gain.to_sym
  end

  def status
    p @device_path
    p @gain
    p @latch_pin
    p @hw_shdn_pin
  end

  private

  # デバイス名または番号からデバイスパスを解決
  def resolve_device(device)
    case device
    when 0, :ce0 then CE0
    when 1, :ce1 then CE1
    else device.to_s
    end
  end

  # SPI 通信でバイト列を送信
  def transfer(*bytes)
    @spi.xfer(txdata: bytes.pack('C*'))
  end
end

if __FILE__ == $PROGRAM_NAME
  mcp4821 = MCP4821.new(MCP4821::CE1)
  (0..4095).each do |dac|
    mcp4821.write(dac)
  end
  sleep 5
  mcp4821.shdn
end
