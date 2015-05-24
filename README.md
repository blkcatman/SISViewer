# SISViewer
Stereo VR Viewer using spherical Image

##概要
カラー＋デプス動画による、VRパノラマムービーを実現するVRビューワーです。

##使用方法
お使いのMacからビルドして、実機に転送してください。   
テスト用の動画は以下のフォルダに入っているファイルを使用してください。   
https://copy.com/NWrWspj4TJ19SaU8   
testmovie.mp4とtestmovie.pngをXcodeのリソースして、プロジェクトのBuild PhasesのCopy Bundle Resourcesに
二つのファイルを加え、MasterViewController.mの#ifdef DEBUGから#endifまでのコメントをはずしたら、
ネット経由からDLしなくてもテストできるようになります。(ただし上記のファイル削除ができなくなります)

##ライセンスについて
Copyright (c) 2014 Tatsuro Matsubara

MITライセンスのもとで公開しています。
http://opensource.org/licenses/mit-license.php
