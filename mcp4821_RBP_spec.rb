# frozen_string_literal: true

begin
  require 'spi'
rescue LoadError
  # spi gem がインストールされていない開発環境（Windows等）でもテストできるようにスタブクラスを定義
  class SPI
    attr_accessor :speed

    def initialize(device:); end

    def xfer(txdata:)
      "\x00" * txdata.bytesize
    end
  end

  $LOADED_FEATURES << 'spi.rb'
end

require_relative 'mcp4821_RBP'

RSpec.describe MCP4821 do
  let(:spi_mock) { instance_double(SPI, 'speed=': nil) }
  let(:mcp4821) do
    allow(SPI).to receive(:new).with(device: described_class::CE0).and_return(spi_mock)
    described_class.new
  end

  describe '定数の定義' do
    it 'デバイスパス定数が正しく設定されていること' do
      expect(described_class::CE0).to eq('/dev/spidev0.0')
      expect(described_class::CE1).to eq('/dev/spidev0.1')
    end

    it 'ゲインコマンド定数が正しく設定されていること' do
      expect(described_class::CMD_GAIN_X1).to eq(0b0011)
      expect(described_class::CMD_GAIN_X2).to eq(0b0001)
    end
  end

  describe '#initialize' do
    it 'デフォルトで CE0、1MHz のクロック速度、ゲイン :x1 を設定すること' do
      expect(SPI).to receive(:new).with(device: '/dev/spidev0.0').and_return(spi_mock)
      expect(spi_mock).to receive(:speed=).with(1_000_000)

      dac = described_class.new
      expect(dac.device_path).to eq('/dev/spidev0.0')
      expect(dac.speed_hz).to eq(1_000_000)
      expect(dac.gain).to eq(:x1)
    end

    it '数値 0 またはシンボル :ce0 を CE0 パスに解決すること' do
      expect(SPI).to receive(:new).with(device: '/dev/spidev0.0').twice.and_return(spi_mock)

      expect(described_class.new(0).device_path).to eq('/dev/spidev0.0')
      expect(described_class.new(:ce0).device_path).to eq('/dev/spidev0.0')
    end

    it '数値 1 またはシンボル :ce1 を CE1 パスに解決すること' do
      expect(SPI).to receive(:new).with(device: '/dev/spidev0.1').twice.and_return(spi_mock)

      expect(described_class.new(1).device_path).to eq('/dev/spidev0.1')
      expect(described_class.new(:ce1).device_path).to eq('/dev/spidev0.1')
    end

    it '任意のデバイス文字列パスを渡して初期化できること' do
      expect(SPI).to receive(:new).with(device: '/dev/spidev1.0').and_return(spi_mock)
      dac = described_class.new('/dev/spidev1.0')
      expect(dac.device_path).to eq('/dev/spidev1.0')
    end
  end

  describe '#write' do
    context 'dac が 1845 (0x735)、デフォルトゲイン (:x1) の場合' do
      let(:dac) { 1845 }

      it 'コマンド 0b0011 と 12bit DAC 値を結合した2バイト [0x37, 0x35] を送信すること' do
        expected_tx = [0b00110111, 0b00110101].pack('C*')
        expect(spi_mock).to receive(:xfer).with(txdata: expected_tx).and_return(expected_tx)

        expect(mcp4821.write(dac)).to eq(expected_tx)
      end
    end

    context 'ゲインに :x2 (または "x2") を一時指定した場合' do
      let(:dac) { 2047 }

      it 'コマンド 0b0001 と 12bit DAC 値を結合した2バイト [0x17, 0xFF] を送信すること' do
        expected_tx = [0b00010111, 0b11111111].pack('C*')
        expect(spi_mock).to receive(:xfer).with(txdata: expected_tx).twice.and_return(expected_tx)

        mcp4821.write(dac, :x2)
        mcp4821.write(dac, 'x2')
      end
    end

    context '境界値（0 および 4095）の場合' do
      it 'dac = 0 のとき [0x30, 0x00] を送信すること' do
        expected_tx = [0x30, 0x00].pack('C*')
        expect(spi_mock).to receive(:xfer).with(txdata: expected_tx)
        mcp4821.write(0)
      end

      it 'dac = 4095 のとき [0x3F, 0xFF] を送信すること' do
        expected_tx = [0x3F, 0xFF].pack('C*')
        expect(spi_mock).to receive(:xfer).with(txdata: expected_tx)
        mcp4821.write(4095)
      end
    end
  end

  describe '#set_out_gain / #set_gain' do
    it 'デフォルトの出力ゲインを変更し、以降の #write に反映すること' do
      mcp4821.set_out_gain('x2')
      expect(mcp4821.gain).to eq(:x2)

      expected_tx = [0x17, 0xFF].pack('C*')
      expect(spi_mock).to receive(:xfer).with(txdata: expected_tx)
      mcp4821.write(2047)

      mcp4821.set_gain(:x1)
      expect(mcp4821.gain).to eq(:x1)
    end
  end

  describe '#shdn' do
    it 'ソフトウェアシャットダウンとして [0x00, 0x00] を送信すること' do
      expected_tx = [0, 0].pack('C*')
      expect(spi_mock).to receive(:xfer).with(txdata: expected_tx)
      mcp4821.shdn
    end
  end

  describe 'ラッチ（LDAC）ピン制御' do
    let(:pin) { 22 }

    describe '#set_latch_pin' do
      it '未エクスポート時に GPIO を export し、direction を out に設定すること' do
        expect(Dir).to receive(:exist?).with('/sys/class/gpio/gpio22').and_return(false)
        expect(File).to receive(:write).with('/sys/class/gpio/export', '22').ordered
        expect(File).to receive(:write).with('/sys/class/gpio/gpio22/direction', 'out').ordered

        mcp4821.set_latch_pin(pin)
        expect(mcp4821.latch_pin).to eq(pin)
      end

      it 'エクスポート済みの場合は export をスキップして direction を out に設定すること' do
        expect(Dir).to receive(:exist?).with('/sys/class/gpio/gpio22').and_return(true)
        expect(File).not_to receive(:write).with('/sys/class/gpio/export', anything)
        expect(File).to receive(:write).with('/sys/class/gpio/gpio22/direction', 'out')

        mcp4821.set_latch_pin(pin)
      end
    end

    context 'latch_pin 設定済みの場合' do
      before do
        allow(Dir).to receive(:exist?).and_return(true)
        allow(File).to receive(:write)
        mcp4821.set_latch_pin(pin)
      end

      it '#set_without_latch で LDAC ピンに 0 (Low) を書き込むこと' do
        expect(File).to receive(:write).with('/sys/class/gpio/gpio22/value', '0')
        mcp4821.set_without_latch
      end

      it '#set_with_latch で LDAC ピンに 1 (High) を書き込むこと' do
        expect(File).to receive(:write).with('/sys/class/gpio/gpio22/value', '1')
        mcp4821.set_with_latch
      end

      it '#latch で LDAC ピンに 0 (Low) -> 1 (High) の順でパルスを書き込むこと' do
        expect(File).to receive(:write).with('/sys/class/gpio/gpio22/value', '0').ordered
        expect(File).to receive(:write).with('/sys/class/gpio/gpio22/value', '1').ordered
        mcp4821.latch
      end
    end

    context 'latch_pin 未設定の場合' do
      it '各ラッチ操作メソッドで RuntimeError を発生させること' do
        expect { mcp4821.set_without_latch }.to raise_error(RuntimeError, /latch_pin/)
        expect { mcp4821.set_with_latch }.to raise_error(RuntimeError, /latch_pin/)
        expect { mcp4821.latch }.to raise_error(RuntimeError, /latch_pin/)
      end
    end
  end

  describe 'ハードウェアシャットダウン（SHDN）ピン制御' do
    let(:pin) { 27 }

    describe '#set_hw_shdn_pin' do
      it 'GPIO を export し、direction を out に設定すること' do
        expect(Dir).to receive(:exist?).with('/sys/class/gpio/gpio27').and_return(false)
        expect(File).to receive(:write).with('/sys/class/gpio/export', '27').ordered
        expect(File).to receive(:write).with('/sys/class/gpio/gpio27/direction', 'out').ordered

        mcp4821.set_hw_shdn_pin(pin)
        expect(mcp4821.hw_shdn_pin).to eq(pin)
      end
    end

    context 'hw_shdn_pin 設定済みの場合' do
      before do
        allow(Dir).to receive(:exist?).and_return(true)
        allow(File).to receive(:write)
        mcp4821.set_hw_shdn_pin(pin)
      end

      it '#hw_shdn で SHDN ピンに 0 (Low) を書き込むこと' do
        expect(File).to receive(:write).with('/sys/class/gpio/gpio27/value', '0')
        mcp4821.hw_shdn
      end

      it '#hw_shdn_release で SHDN ピンに 1 (High) を書き込むこと' do
        expect(File).to receive(:write).with('/sys/class/gpio/gpio27/value', '1')
        mcp4821.hw_shdn_release
      end
    end

    context 'hw_shdn_pin 未設定の場合' do
      it '各シャットダウン操作メソッドで RuntimeError を発生させること' do
        expect { mcp4821.hw_shdn }.to raise_error(RuntimeError, /hw_shdn_pin/)
        expect { mcp4821.hw_shdn_release }.to raise_error(RuntimeError, /hw_shdn_pin/)
      end
    end
  end
end
