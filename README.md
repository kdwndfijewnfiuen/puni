# YWPOverlay

妖怪ウォッチぷにぷに用のステータスオーバーレイ dylib。

表示内容:

- Yマネー (Y$)
- Yポイント (YP)
- 人魂
- アクティブデッキ 5 体の妖怪 ID

## 必要環境

- [Theos](https://theos.dev/)
- iOS 向け toolchain
- 脱獄デバイス（Substrate / Substitute / libhooker）
- 対象アプリ: `YWP`

## ビルド

```bash
cd YWPOverlay
make package
```

生成物は `packages/` 以下の `.deb`。

rootless じゃなく rootful の場合は `Makefile` の次を消す:

```make
THEOS_PACKAGE_SCHEME = rootless
```

## インストール

```bash
# 例: scp して device 上で
dpkg -i jp.local.ywpoverlay_0.1.0_iphoneos-arm64.deb
killall YWP
```

または `make package install`（`THEOS_DEVICE_IP` 設定時）。

## オーバーレイ操作

| 操作 | 動作 |
|------|------|
| ドラッグ | 位置移動 |
| ダブルタップ | 折りたたみ / 展開 |

値が `---` のときは、まだ `Tweak.mm` の read 関数が未実装です。

## オフセットの埋め方

`Tweak.mm` の次を実装する:

1. `getUserDataPtr()` — UserData（または同等）のベースポインタ
2. `readYmoney()` / `readYpoint()` / `readHitodama()`
3. `readDeckIds()` — 5 体の youkaiId

### H5Frida での探し方（例: 人魂）

1. 人魂数をメモ
2. H5GG / Frida でその値を検索
3. 1 消費して絞り込み
4. ポインタスキャンで安定アドレス or グローバルからのオフセットを特定
5. `readHitodama` に反映

Y$ / YP / デッキも同様。

バイナリ内のプロトコル名の目安:

- `ymoney`, `chargeYmoney`
- `hitodama`, `freeHitodama`
- `activeDeckId`, `youkaiIdList`

## ファイル

```
YWPOverlay/
├── Makefile
├── control
├── YWPOverlay.plist   # Filter: YWP only
├── Tweak.mm           # 本体
└── README.md
```

## ライセンス

個人利用向け。自己責任で。
