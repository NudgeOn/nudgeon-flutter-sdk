Pod::Spec.new do |s|
  s.name             = "nudgeon_flutter"
  s.version          = "0.1.0"
  s.summary          = "NudgeOn 고객 인게이지먼트 플랫폼 Flutter SDK (네이티브 코어 브리지)"
  s.license          = { :type => "Apache-2.0", :file => "../LICENSE" }
  s.author           = { "NudgeOn" => "dev@nudgeon.io" }
  s.homepage         = "https://github.com/nudgeon/nudgeon-flutter-sdk"
  s.source           = { :path => "." }
  s.source_files     = "Classes/**/*"
  s.platform         = :ios, "15.0"
  s.swift_version    = "5.9"

  s.dependency "Flutter"
  s.dependency "NudgeOnSDK" # 네이티브 코어 — 상태 보유자 (PRD-01A 1.1)
end
