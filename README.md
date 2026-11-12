# MCP4821 on Raspberry Pi

Raspberry Pi 上で SPI 接続された 12-bit D/A コンバータ **MCP4821** を制御するための Ruby スクリプト・ライブラリです。  
`spi` gem を使用し、Linux カーネル標準の SPI ドライバ（`/dev/spidev0.x`）経由で通信を行います。また、Linux 標準の `sysfs`（`/sys/class/gpio`）経由での $\overline{\text{LDAC}}$ ピン・$\overline{\text{SHDN}}$ ピン制御にも対応しています。

12ビット分解能（0〜4095）でのアナログ電圧出力、内蔵基準電圧（$V_{\text{REF}} = 2.048\text{V}$）に対するゲイン切り替え（`1x`: 0〜2.048V / `2x`: 0〜4.096V）、ラッチ同期更新、およびソフトウェア／ハードウェアシャットダウンに対応しています。

---

## 前提条件

- Raspberry Pi (Raspberry Pi OS)
- Ruby 3.x / 4.x
- `spi` gem
- Raspberry Pi の SPI インターフェースが有効化されていること
  ```bash
  sudo raspi-config
  # [Interface Options] -> [SPI] -> 有効化 (Yes)
  ```
  ※ 一般ユーザーで実行する場合は、ユーザーが `spi` および `gpio` グループに所属している必要があります（デフォルトの `pi` ユーザー等は通常設定済みです）。

---

## ハードウェア接続（配線例）

MCP4821（PDIP / SOIC / MSOP 8ピン）と Raspberry Pi のピン接続対応表です。

| MCP4821 ピン | ピン名 | Raspberry Pi ピン（例: CE0利用時） | 備考 |
|---|---|---|---|
| 1 | $\text{V}_{\text{DD}}$ | 3.3V (Pin 1) または 5V (Pin 2) | 電源 (2.7V〜5.5V) ※2xゲインで4.096Vまで出力する場合は5V |
| 2 | $\overline{\text{CS}}$ | GPIO 8 (Pin 24 / SPI0 CE0) | チップセレクト |
| 3 | SCK | GPIO 11 (Pin 23 / SPI0 SCLK) | シリアルクロック入力 |
| 4 | SDI | GPIO 10 (Pin 19 / SPI0 MOSI) | シリアルデータ入力 |
| 5 | $\overline{\text{LDAC}}$ | GND または 任意の GPIO（例: GPIO 22） | ラッチ入力（即時更新のみなら GND 固定可） |
| 6 | $\overline{\text{SHDN}}$ | $\text{V}_{\text{DD}}$ または 任意の GPIO（例: GPIO 27） | ハードウェアシャットダウン入力（未使用時は $\text{V}_{\text{DD}}$ 接続） |
| 7 | $\text{V}_{\text{SS}}$ | GND (Pin 6 等) | グランド |
| 8 | $\text{V}_{\text{OUT}}$ | アナログ電圧出力先 | D/A アナログ出力 |

※ CE1 (GPIO 7 / Pin 26) を使用する場合は、初期化時に `MCP4821::CE1`（または `1`, `:ce1`）を指定してください。

---

## インストール・環境設定

### 依存 Gem のインストール

```bash
gem install spi
```

Bundler を使用する場合は `Gemfile` に以下を記述して `bundle install` を実行してください：

```ruby
source 'https://rubygems.org'
gem 'spi'
```

---

## 使い方

### 1. ライブラリとして使用する場合

```ruby
require_relative 'mcp4821_RBP'

# インスタンス作成（デフォルトは CE0: '/dev/spidev0.0'、クロック 1MHz、ゲイン :x1）
# CE1 を使用する場合は MCP4821.new(MCP4821::CE1) または MCP4821.new(1)
dac = MCP4821.new

# --- 基本的な電圧出力 ---
# DAC 値（0〜4095）の書き込み（ゲイン :x1 の場合、2048 で約 1.024V を出力）
dac.write(2048)

# 出力ゲインを :x2（フルスケール 4.096V）に変更して出力
dac.set_out_gain(:x2)
dac.write(2048) # 約 2.048V を出力

# 一時的にゲインを指定して書き込むことも可能
dac.set_out_gain(:x1)
dac.write(2048, :x2)

# ソフトウェアシャットダウン（出力をハイインピーダンス 500kΩ にして省電力化）
dac.shdn

# --- LDAC ピンによるラッチ制御（GPIO 接続時） ---
dac.set_latch_pin(22)   # GPIO 22 を LDAC ピンとして設定
dac.set_with_latch      # LDAC を High に保持（write してもすぐには VOUT に反映されない）
dac.write(4095)         # 入力レジスタへ書き込み
dac.latch               # LDAC に Low -> High パルスを送り、VOUT を更新
dac.set_without_latch   # LDAC を Low に固定（write と同時に即時更新するモード）

# --- SHDN ピンによるハードウェアシャットダウン制御（GPIO 接続時） ---
dac.set_hw_shdn_pin(27) # GPIO 27 を SHDN ピンとして設定
dac.hw_shdn             # SHDN を Low にしてハードウェアシャットダウン
dac.hw_shdn_release     # SHDN を High にして通常動作へ復帰
```

#### 出力電圧の計算式
$$V_{\text{OUT}} = \frac{2.048\text{V} \times D_n}{4096} \times G$$
- $D_n$: DAC 入力コード（`0`〜`4095`）
- $G$: ゲイン選択（`:x1` のとき `1`、`:x2` のとき `2`）

### 2. サンプルスクリプトを直接実行する場合

`mcp4821_RBP.rb` を直接実行すると、CE1 に接続された MCP4821 に対して `0` から `4095` まで順次出力し、5秒後にソフトウェアシャットダウンします。

```bash
ruby mcp4821_RBP.rb
```

---

## 定数一覧

| 定数名 | デフォルト値 | 説明 |
|---|---|---|
| `CE0` | `'/dev/spidev0.0'` | SPI チップセレクト 0 デバイスパス |
| `CE1` | `'/dev/spidev0.1'` | SPI チップセレクト 1 デバイスパス |
| `CMD_GAIN_X1` | `0b0011` | 書き込みコマンド上位4ビット（Gain = 1x, Active） |
| `CMD_GAIN_X2` | `0b0001` | 書き込みコマンド上位4ビット（Gain = 2x, Active） |
| `DEFAULT_SPEED_HZ` | `1_000_000` | デフォルト SPI クロック周波数 (1 MHz) |

---

## テストの実行

RSpec を使用して単体テストを実行できます（SPI 通信部および GPIO ファイル操作はモック化されているため、Windows / macOS 等の開発 PC 上でも実行可能です）。

```bash
rspec mcp4821_RBP_spec.rb
```
