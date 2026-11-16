# Frameworks keep the Legacy VM modules in separate signed symbol namespaces.
foreach(pair "etl:ETPadEngine" "renderer_es:ETPadRenderer" "cgame:ETPadCGame" "ui:ETPadUI" "qagame:ETPadGame" "tvgame:ETPadTVGame")
    string(REPLACE ":" ";" parts "${pair}")
    list(GET parts 0 target)
    list(GET parts 1 name)
    if(TARGET ${target})
        set_target_properties(${target} PROPERTIES FRAMEWORK TRUE FRAMEWORK_VERSION A
            OUTPUT_NAME "${name}" PREFIX "" SUFFIX ""
            MACOSX_FRAMEWORK_IDENTIFIER "com.etpad.${name}"
            LIBRARY_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/frameworks"
            LIBRARY_OUTPUT_DIRECTORY_RELEASE "${CMAKE_BINARY_DIR}/frameworks"
            INSTALL_NAME_DIR "@rpath")
    endif()
endforeach()

set(ETPAD_ANGLE_ROOT "${CMAKE_SOURCE_DIR}/build/dependencies/angle-prebuilt/ios")
if(CMAKE_OSX_SYSROOT MATCHES "[Ss]imulator")
    set(ETPAD_ANGLE_SLICE "ios-arm64_x86_64-simulator")
else()
    set(ETPAD_ANGLE_SLICE "ios-arm64")
endif()
set(ETPAD_EGL "${ETPAD_ANGLE_ROOT}/libEGL.xcframework/${ETPAD_ANGLE_SLICE}/libEGL.framework")
set(ETPAD_GLES2 "${ETPAD_ANGLE_ROOT}/libGLESv2.xcframework/${ETPAD_ANGLE_SLICE}/libGLESv2.framework")
target_sources(etl PRIVATE apple/ios/angle_sdl.c apple/ios/module_loader.m)
target_sources(renderer_es PRIVATE apple/ios/gl4es_context.c)
foreach(target etl renderer_es)
    target_include_directories(${target} PRIVATE "${ETPAD_ANGLE_ROOT}/include")
    target_link_libraries(${target} "${ETPAD_EGL}" "${ETPAD_GLES2}")
endforeach()
