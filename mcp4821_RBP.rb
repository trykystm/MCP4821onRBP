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

  GPIO_BASE_PATH = '/sys/class/gpio'
  GPIO_LOW = '0'
  GPIO_HIGH = '1'

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

  # LDAC ピンを Low に固定（SPI 書き込みと同時に VOUT を即時更新）
  def set_without_latch
    require_pin!(@latch_pin, 'latch_pin')
    write_gpio(@latch_pin, GPIO_LOW)
  end

  # LDAC ピンを High に保持（latch メソッド呼び出しまで VOUT の更新を待機）
  def set_with_latch
    require_pin!(@latch_pin, 'latch_pin')
    write_gpio(@latch_pin, GPIO_HIGH)
  end

  # LDAC ピンに Low -> High パルスを入力して入力レジスタの値を VOUT に反映
  def latch
    require_pin!(@latch_pin, 'latch_pin')
    write_gpio(@latch_pin, GPIO_LOW)
    write_gpio(@latch_pin, GPIO_HIGH)
  end

  # ソフトウェアシャットダウン（SHDNビット = 0）
  def shdn
    transfer(0, 0)
  end

  # SHDN ピンを Low にしてハードウェアシャットダウン状態へ移行
  def hw_shdn
    require_pin!(@hw_shdn_pin, 'hw_shdn_pin')
    write_gpio(@hw_shdn_pin, GPIO_LOW)
  end

  # SHDN ピンを High にしてハードウェアシャットダウンを解除
  def hw_shdn_release
    require_pin!(@hw_shdn_pin, 'hw_shdn_pin')
    write_gpio(@hw_shdn_pin, GPIO_HIGH)
  end

  # ハードウェアシャットダウン（SHDN）制御用 GPIO ピン番号を設定
  def set_hw_shdn_pin(pin)
    @hw_shdn_pin = pin
    setup_gpio_output(pin)
  end

  # ラッチ（LDAC）制御用 GPIO ピン番号を設定
  def set_latch_pin(pin)
    @latch_pin = pin
    setup_gpio_output(pin)
  end

  # 出力ゲインを設定（:x1 または :x2）
  def set_out_gain(gain = :x1)
    @gain = gain.to_sym
  end
  alias set_gain set_out_gain

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

  # ピン番号が設定されているか検証
  def require_pin!(pin, name)
    raise "#{name} が設定されていません" if pin.nil?
  end

  # sysfs 経由で GPIO ピンを出力モードに初期化
  def setup_gpio_output(pin)
    pin_dir = "#{GPIO_BASE_PATH}/gpio#{pin}"
    File.write("#{GPIO_BASE_PATH}/export", pin.to_s) unless Dir.exist?(pin_dir)
    File.write("#{pin_dir}/direction", 'out')
  end

  # sysfs 経由で GPIO ピンの出力値を変更
  def write_gpio(pin, value)
    File.write("#{GPIO_BASE_PATH}/gpio#{pin}/value", value.to_s)
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
