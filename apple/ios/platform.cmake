# iOS platform additions; desktop Apple configuration remains upstream-owned.
target_link_libraries(os_libraries INTERFACE dl m objc "-framework Foundation" "-framework UIKit" "-framework CoreFoundation" "-framework QuartzCore" "-framework Metal" "-framework GameController")
set(ETL_ARCH_COUNT 1)
set(ETL_ARM 1)
set(CMAKE_OSX_ARCHITECTURES_ arm64)
find_package(Iconv REQUIRED)
target_link_libraries(os_libraries INTERFACE Iconv::Iconv)
# SDL's static UIKit/audio/controller backends require these system frameworks.
foreach(framework CoreVideo CoreAudio AudioToolbox AVFoundation CoreBluetooth CoreGraphics CoreMotion OpenGLES CoreHaptics)
    target_link_libraries(os_libraries INTERFACE "-framework ${framework}")
endforeach()
