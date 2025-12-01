Pod::Spec.new do |s|
  s.name          = "LocalMasonry"
  s.version       = "1.1.0"
  s.summary       = "Harness the power of Auto Layout NSLayoutConstraints with a simplified, chainable and expressive syntax."
  s.description   = <<-DESC
    Masonry is a light-weight layout framework which wraps AutoLayout with a nicer syntax.
    Masonry has its own layout DSL which provides a chainable way of describing your
    NSLayoutConstraints which results in layout code that is more concise and readable.
    Masonry supports iOS and Mac OS X.
  DESC
  s.homepage      = "https://github.com/SnapKit/Masonry"
  s.license       = { :type => "MIT", :file => "LICENSE" }
  s.author        = { "Jonas Budelmann" => "jonas.budelmann@gmail.com" }
  s.platform      = :ios, "9.0"
  s.source        = { :path => "." }
  s.module_name   = "Masonry"
  
  s.source_files  = "Masonry/**/*.{h,m}"
  s.public_header_files = "Masonry/**/*.h"
  s.requires_arc   = true
end
