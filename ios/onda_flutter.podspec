Pod::Spec.new do |s|
  s.name             = "onda_flutter"
  s.version          = "0.1.0"
  s.summary          = "Onda 고객 인게이지먼트 플랫폼 Flutter SDK (네이티브 코어 브리지)"
  s.license          = { :type => "MIT" }
  s.author           = { "Onda" => "dev@onda.io" }
  s.homepage         = "https://github.com/ondahq/onda-flutter-sdk"
  s.source           = { :path => "." }
  s.source_files     = "Classes/**/*"
  s.platform         = :ios, "15.0"
  s.swift_version    = "5.9"

  s.dependency "Flutter"
  s.dependency "OndaSDK" # 네이티브 코어 — 상태 보유자 (PRD-01A 1.1)
end
