# Gyaim - extend(Function)

 * [Gyaim](http://github.com/masui/Gyaim)の拡張版です。
 * とりあえずMac OS X Lion(10.7.4)で動くことを確認
 * 基本的な機能（辞書、変換、Google 日本語入力利用など）はそのままです。

# インストール
 * [Gyaim](http://github.com/masui/Gyaim)を参考にmake installしてみてください。

#基本動作の変更点
 * 矢印キーによって変換候補のウィンドウを移動できる（右・下キーで次へ、左、上キーで戻る）

# ファンクションキーによる動作（一部未実装）
 * F1 Key : 類語変換(ex.寝る→就寝)
 * F2 Key : 連想語変換(ex.クイズ→アメリカ横断ウルトラクイズ)
 * F3 Key : Google サジェスト変換（ex.夫→夫がオオアリクイに食べられました）
 * F4 Key : Google 日本語入力変換(連文節変換）
 * F5 Key : 和英・英和翻訳(ex.寝る→bed, turn in, go to bed, bed→ベッド、寝床…)
 * F6 Key : ひらがな変換
 * F7 Key : カタカナ変換

それぞれ、キー入力した時点での変換候補に対して動作します。

#使用例
neru→(Space)→練る→(Space)→寝る→(F1 Key)→臥する→(F2 Key)→Lie Down

#更新履歴

#やろうと思っていること