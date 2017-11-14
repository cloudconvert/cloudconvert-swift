Pod::Spec.new do |s|

  s.name         = "CloudConvert"
  s.version      = "1.0.3"
  s.summary      = "Convert between 200 supported file formats"

  s.description  = <<-DESC
                    CloudConvert offers a file conversion API. More than 200 different formats are supported:

                    * document (PDF, DOC, DOCX, ODT, RTF, TXT...)
                    * image (PNG, JPG, SVG, WEBP, TIF, RAW...)
                    * video (MP4, MKV, AVI, MPG, 3GP, FLV, WMV, OGG...)
                    * audio (MP3, AAC, M4A, FLAC, WMA, WAV...)
                    * ebook (MOBI, EPBUB, CBC, AZW...)
                    * archive (ZIP, RAR, 7Z, TAR.BZ2...)
                    * spreadsheet (XLS, XLSX, ODS, CSV...)
                    * presentation (PPT, PPTX, ODP...)
                   DESC

  s.homepage     = "https://cloudconvert.com"

  s.license      = "MIT"

  s.author             = { "Josias Montag" => "josias@montag.info" }

  s.ios.deployment_target = '9.0'
  s.osx.deployment_target = '10.9'

  s.source = { :git => 'https://github.com/cloudconvert/cloudconvert-swift.git', :tag => s.version }

  s.source_files = 'CloudConvert/*.swift'

  s.dependency "Alamofire", "~> 4.5"


end
