module Langusta
  class LanguageDetectionFacade
    def initialize
      @factory = DetectorFactory.new
      profiles = load_profiles()
      profiles.each_with_index do |profile, index|
        @factory.add_profile(profile, index, profiles.length)
      end
    end

    def detect(ucs2_string)
      detector = @factory.create()
      detector.append(ucs2_string)
      detector.detect()
    end

    private
    def load_profiles
      Dir[File.join(DEFAULT_PROFILE_PATH, '/*')].map do |filename|
        LangProfile.load_from_file(filename)
      end
    end
  end
end